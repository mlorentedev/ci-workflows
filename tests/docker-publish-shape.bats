#!/usr/bin/env bats
#
# The shape of docker-publish.yml (spec CI-010 AC2, issue #11): it pushes by
# digest, scans every platform by digest, and tags only after the gate passed.

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/docker-publish.yml"
ACTION="${BATS_TEST_DIRNAME}/../.github/actions/docker-build/action.yml"

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

# The composite's push-by-digest mode, which the workflow relies on.

resolve() { run bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/resolve.sh"; }
output_of() { sed -n "s/^$1=//p" "${GITHUB_OUTPUT}" | tail -1; }

setup() {
  export GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/output"
  : >"${GITHUB_OUTPUT}"
  yq '.runs.steps[] | select(.id == "resolve") | .run' "${ACTION}" >"${BATS_TEST_TMPDIR}/resolve.sh"
  export IMAGE=docker.io/owner/app CACHE_SCOPE="" CACHE_MODE=max CACHE_FROM="" CACHE_TO="" LOAD=false PUSH=false PUSH_BY_DIGEST=false
}

@test "push-by-digest pushes the image under its name and no tag" {
  PUSH_BY_DIGEST=true resolve
  [ "$status" -eq 0 ]
  [ "$(output_of outputs)" = "type=image,name=docker.io/owner/app,push-by-digest=true,name-canonical=true,push=true" ]
}

@test "push-by-digest excludes load and push, which would name a tag" {
  PUSH_BY_DIGEST=true LOAD=true resolve
  [ "$status" -ne 0 ]
  PUSH_BY_DIGEST=true PUSH=true resolve
  [ "$status" -ne 0 ]
}

@test "without push-by-digest the composite names no output" {
  resolve
  [ "$(output_of outputs)" = "" ]
}

@test "the composite passes the resolved output and drops tags when it pushes by digest" {
  [ "$(yq '.runs.steps[] | select(.id == "build") | .with.outputs' "${ACTION}")" = '${{ steps.resolve.outputs.outputs }}' ]
  [ "$(yq '.runs.steps[] | select(.id == "build") | .with.tags' "${ACTION}")" = "\${{ inputs.push-by-digest != 'true' && (inputs.tags || inputs.image) || '' }}" ]
}
