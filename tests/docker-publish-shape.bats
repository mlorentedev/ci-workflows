#!/usr/bin/env bats
#
# The shape of docker-publish.yml (spec CI-010 AC2, issue #11): it pushes by
# digest, scans every platform by digest, and tags only after the gate passed.

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/docker-publish.yml"

job() { yq ".jobs.$1.$2" "${WORKFLOW}"; }
jstep() { yq ".jobs.$1.steps[] | select(.id == \"$2\") | .$3" "${WORKFLOW}"; }

@test "it is reusable only, and owns no caller-level keys" {
  [ "$(yq '.on | keys | join(",")' "${WORKFLOW}")" = "workflow_call" ]
  [ "$(yq 'has("permissions") or has("concurrency")' "${WORKFLOW}")" = "false" ]
}

@test "registry credentials are declared by name, required, and never inherited" {
  [ "$(yq '.on.workflow_call.secrets | keys | sort | join(",")' "${WORKFLOW}")" = "REGISTRY_TOKEN,REGISTRY_USERNAME" ]
  [ "$(yq '.on.workflow_call.secrets.REGISTRY_TOKEN.required' "${WORKFLOW}")" = "true" ]
  [ "$(yq '.on.workflow_call.secrets.REGISTRY_USERNAME.required' "${WORKFLOW}")" = "true" ]
  run bash -c "yq '... comments=\"\"' '${WORKFLOW}' | grep -E 'secrets: *inherit'"
  [ "$status" -ne 0 ]
}

@test "security-events: write is granted to the scan job alone" {
  [ "$(job scan permissions.security-events)" = "write" ]
  [ "$(yq '[.jobs[] | select(.permissions.security-events == "write")] | length' "${WORKFLOW}")" = "1" ]
  [ "$(yq '[.jobs[] | select(has("permissions") | not)] | length' "${WORKFLOW}")" = "0" ]
}

@test "the build pushes by digest only, through the composite" {
  # A reusable workflow's ./ path is the caller's checkout, so the composite is
  # referenced in this repository, by full SHA.
  jstep build build uses | grep -qE '^mlorentedev/ci-workflows/\.github/actions/docker-build@[0-9a-f]{40}$'

  [ "$(jstep build build with.push-by-digest)" = "true" ]
  [ "$(jstep build build with.tags)" = "null" ]
  [ "$(job build outputs.digest)" = '${{ steps.build.outputs.digest }}' ]
}

@test "the scan runs once per platform, on the digest, after the build" {
  [ "$(job scan needs)" = "build" ]
  [ "$(job scan strategy.matrix.platform)" = '${{ fromJSON(needs.build.outputs.platforms) }}' ]
  [ "$(job scan strategy.fail-fast)" = "false" ]
  local step
  for step in report gate; do
    [ "$(jstep scan "${step}" with.image-ref)" = '${{ inputs.image }}@${{ needs.build.outputs.digest }}' ]
    [ "$(jstep scan "${step}" env.TRIVY_PLATFORM)" = '${{ matrix.platform }}' ]
  done
}

@test "the gate fails on CRITICAL, and the report is uploaded under the category and the platform" {
  [ "$(jstep scan gate with.severity)" = "CRITICAL" ]
  [ "$(jstep scan gate with.exit-code)" = "1" ]
  [ "$(jstep scan gate continue-on-error)" = "null" ]
  [ "$(jstep scan report continue-on-error)" = "true" ]
  [ "$(jstep scan upload continue-on-error)" = "true" ]
  jstep scan upload with.category | grep -qF '${{ inputs.sarif-category }}-'
  [ "$(jstep scan platform-key env.PLATFORM)" = '${{ matrix.platform }}' ]
}

@test "tags are applied last, to the scanned digest, and nothing before the gate names a tag" {
  [ "$(job tag needs | yq 'sort | join(",")')" = "build,scan" ]
  yq '.jobs.tag.steps[].run | select(. != null)' "${WORKFLOW}" | grep -q 'imagetools create'
  yq '.jobs.tag.steps[].run | select(. != null)' "${WORKFLOW}" | grep -qF '${IMAGE}@${DIGEST}'
  run bash -c "yq '.jobs.build, .jobs.scan' '${WORKFLOW}' | grep -F 'inputs.tags'"
  [ "$status" -ne 0 ]
}

@test "every third-party action is pinned by full SHA with its tag as a comment" {
  local uses pinned
  uses=$(grep -E '^\s+(- )?uses: [^.]' "${WORKFLOW}" | grep -cv 'mlorentedev/ci-workflows/')
  pinned=$(grep -cE '^\s+(- )?uses: [a-z0-9-]+/[a-z0-9/-]+@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$' "${WORKFLOW}")
  [ "${uses}" -ge 5 ]
  [ "${uses}" -eq "${pinned}" ]
}

@test "the scan and tag jobs never check out the caller's code" {
  run bash -c "yq '.jobs.scan.steps[].uses, .jobs.tag.steps[].uses' '${WORKFLOW}' | grep checkout"
  [ "$status" -ne 0 ]
}

@test "labels and the cache inputs pass straight through to the composite" {
  local input
  for input in labels cache-from cache-to; do
    [ "$(yq ".on.workflow_call.inputs.${input}.default" "${WORKFLOW}")" = "" ]
    [ "$(jstep build build with.${input})" = "\${{ inputs.${input} }}" ]
  done
  [ "$(yq '.on.workflow_call.inputs.cache-write.default' "${WORKFLOW}")" = "true" ]
  [ "$(jstep build build with.cache-write)" = '${{ inputs.cache-write }}' ]
}

@test "the composite is pinned at a commit on main that has every input the workflow passes" {
  local sha
  sha=$(jstep build build uses | sed 's/.*@//')
  local repo="${BATS_TEST_DIRNAME}/.."
  git -C "${repo}" cat-file -e "${sha}^{commit}" 2>/dev/null || skip "pinned commit not in this clone"
  # A commit from a pull request's branch is left off main by a squash merge.
  if git -C "${repo}" rev-parse -q --verify origin/main >/dev/null; then
    git -C "${repo}" merge-base --is-ancestor "${sha}" origin/main
  fi
  run bash -c "git -C '${BATS_TEST_DIRNAME}/..' show '${sha}:.github/actions/docker-build/action.yml' | yq '.inputs | keys | .[]'"
  [ "$status" -eq 0 ]
  local passed
  for passed in $(jstep build build with | yq 'keys | .[]'); do
    grep -qx "${passed}" <<<"$output"
  done
}
