#!/usr/bin/env bats
#
# The shape of the reusable release workflow and this repository's release
# config (CI-002, #15). Each workflow rule runs against the workflow and against
# a fixture that breaks it, so a check that stopped matching fails here.

ROOT="${BATS_TEST_DIRNAME}/.."
WORKFLOW="${ROOT}/.github/workflows/release.yml"
BAD="${BATS_TEST_DIRNAME}/fixtures/release-shape-bad.yml"
CONFIG="${ROOT}/release-please-config.json"
MANIFEST="${ROOT}/.release-please-manifest.json"
OUTPUTS="release_created tag_name version"

only_workflow_call() { [ "$(yq '.on | keys | join(",")' "$1")" = "workflow_call" ]; }

requires_release_token() {
  [ "$(yq '.on.workflow_call.secrets | keys | join(",")' "$1")" = "RELEASE_TOKEN" ] &&
    [ "$(yq '.on.workflow_call.secrets.RELEASE_TOKEN.required' "$1")" = "true" ]
}

# A required input would break every caller pinned below it (AGENTS.md rule 5).
defaults_every_input() {
  [ "$(yq '[.on.workflow_call.inputs[] | select(.required == true or has("default") | not)] | length' "$1")" = "0" ]
}

no_branch_literal() { ! yq '... comments=""' "$1" | grep -Ew 'main|master'; }

no_caller_owned_keys() { [ "$(yq 'has("permissions") or has("concurrency")' "$1")" = "false" ]; }

# The check context is `<caller job> / release-please`, so the id is a contract.
one_job_named_release_please() { [ "$(yq '.jobs | keys | join(",")' "$1")" = "release-please" ]; }

# Two hops: the step's output becomes the job's, and the job's the workflow's.
publishes_outputs() {
  local out
  for out in ${OUTPUTS}; do
    [ "$(yq ".on.workflow_call.outputs.${out}.value" "$1")" = "\${{ jobs.release-please.outputs.${out} }}" ] || return 1
    [ "$(yq ".jobs.release-please.outputs.${out}" "$1")" = "\${{ steps.release.outputs.${out} }}" ] || return 1
  done
}

# The PAT makes every API call, so the job's GITHUB_TOKEN needs nothing.
asks_for_no_permissions() { [ "$(yq '.jobs.release-please.permissions | tag + length' "$1")" = '!!map0' ]; }

pins_release_please() {
  grep -Eq '^\s+uses: googleapis/release-please-action@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$' "$1"
}

# The release step authenticates with the caller's token, never GITHUB_TOKEN.
release_uses_the_token() {
  [ "$(yq '.jobs.release-please.steps[] | select(.id == "release") | .with.token' "$1")" = '${{ secrets.RELEASE_TOKEN }}' ]
}

# A missing token fails with its remedy before release-please answers 401.
token_checked_first() {
  local first
  first=$(yq '.jobs.release-please.steps[0]' "$1")
  [ "$(yq '.id' <<<"${first}")" = "token" ] &&
    [ "$(yq '.env.HAS_RELEASE_TOKEN' <<<"${first}")" = "\${{ secrets.RELEASE_TOKEN != '' }}" ] &&
    yq '.run' <<<"${first}" | grep -q 'dotf secrets sync ci --repo .* RELEASE_TOKEN' &&
    yq '.run' <<<"${first}" | grep -q 'exit 1'
}

assert_rule() {
  run "$1" "${WORKFLOW}"
  [ "${status}" -eq 0 ]
  run "$1" "${BAD}"
  [ "${status}" -ne 0 ]
}

@test "workflow_call is the only trigger" { assert_rule only_workflow_call; }
@test "RELEASE_TOKEN is the one secret, and it is required" { assert_rule requires_release_token; }
@test "every input has a default" { assert_rule defaults_every_input; }
@test "no branch name is hard-coded" { assert_rule no_branch_literal; }
@test "top-level permissions and concurrency stay with the caller" { assert_rule no_caller_owned_keys; }
@test "the one job is release-please" { assert_rule one_job_named_release_please; }
@test "release_created, tag_name and version reach the caller" { assert_rule publishes_outputs; }
@test "the job asks GITHUB_TOKEN for nothing" { assert_rule asks_for_no_permissions; }
@test "release-please-action is pinned by full SHA with its tag as a comment" { assert_rule pins_release_please; }
@test "release-please authenticates with RELEASE_TOKEN" { assert_rule release_uses_the_token; }
@test "a missing token fails first, naming the remedy" { assert_rule token_checked_first; }

# The config is this repository's own, so its rules are checked once.
@test "the input defaults name this repository's config files" {
  [ "$(yq '.on.workflow_call.inputs.config_file.default' "${WORKFLOW}")" = "release-please-config.json" ]
  [ "$(yq '.on.workflow_call.inputs.manifest_file.default' "${WORKFLOW}")" = ".release-please-manifest.json" ]
  [ -f "${CONFIG}" ] && [ -f "${MANIFEST}" ]
}

@test "the manifest holds one semver for the root package" {
  [ "$(jq -r 'keys | join(",")' "${MANIFEST}")" = "." ]
  jq -r '.["."]' "${MANIFEST}" | grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+'
}

# Tags stay vX.Y.Z, the form every consumer's pin comment carries.
@test "one root package, tagged without a component" {
  [ "$(jq -r '.packages | keys | join(",")' "${CONFIG}")" = "." ]
  [ "$(jq -r '.["release-type"]' "${CONFIG}")" = "simple" ]
  [ "$(jq -r '.["include-component-in-tag"]' "${CONFIG}")" = "false" ]
}

# The default changelog renders `Refs owner/repo#N` as `closes`, and merging
# the release PR would close those issues (dotfiles CI-005).
@test "the changelog is GitHub's, so the release PR closes nothing" {
  [ "$(jq -r '.["changelog-type"]' "${CONFIG}")" = "github" ]
}

# simple updates version.txt only if it exists (createIfMissing: false); the tag
# is the version, so neither the file nor another version file is wanted.
@test "the release writes no version file" {
  [ "$(jq '[.. | objects | select(has("extra-files") or has("version-file"))] | length' "${CONFIG}")" = "0" ]
  [ ! -e "${ROOT}/version.txt" ]
}
