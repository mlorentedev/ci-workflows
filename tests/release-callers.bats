#!/usr/bin/env bats
#
# The repositories calling release.yml, as fixtures (CI-002, #15), and this
# repository's own caller. Each rule runs against every caller and against a
# fixture that breaks it. A release workflow that drops an input or an output
# breaks here before it breaks a consumer.

bats_require_minimum_version 1.5.0

ROOT="${BATS_TEST_DIRNAME}/.."
WORKFLOW="${ROOT}/.github/workflows/release.yml"
SELF="${ROOT}/.github/workflows/release-please.yml"
CALLERS="${BATS_TEST_DIRNAME}/fixtures/release-callers"
BAD="${BATS_TEST_DIRNAME}/fixtures/release-caller-shape-bad.yml"

keys_of() { yq "$2 | keys | .[]" "$1" | sort; }

passes_only_declared_inputs() {
  [ -z "$(comm -23 <(keys_of "$1" '.jobs.release.with // {}') <(keys_of "${WORKFLOW}" '.on.workflow_call.inputs'))" ]
}

# One secret name across the fleet (ADR-001 decision 6), passed by name.
passes_release_token_by_name() {
  [ "$(yq '.jobs.release.secrets | keys | join(",")' "$1")" = "RELEASE_TOKEN" ] &&
    [ "$(yq '.jobs.release.secrets.RELEASE_TOKEN' "$1")" = '${{ secrets.RELEASE_TOKEN }}' ]
}

# Every needs.release.outputs.<name> a caller reads is one the workflow declares.
reads_only_declared_outputs() {
  [ -z "$(comm -23 <(grep -oE 'needs\.release\.outputs\.[a-z_]+' "$1" | sed 's/.*\.//' | sort -u) \
    <(keys_of "${WORKFLOW}" '.on.workflow_call.outputs'))" ]
}

# A job after the release runs only when this run created one.
publishes_only_a_release() {
  [ "$(yq '[.jobs[] | select([.needs] | flatten | contains(["release"]))
    | select((.if // "") != "needs.release.outputs.release_created == '"'"'true'"'"'")] | length' "$1")" = "0" ]
}

pins_by_full_sha() {
  yq '.jobs.release.uses' "$1" | grep -Eq '^mlorentedev/ci-workflows/\.github/workflows/release\.yml@[0-9a-f]{40}$'
}

assert_rule() {
  local caller
  for caller in "${CALLERS}"/*.yml "${SELF}"; do
    run "$1" "${caller}"
    [ "${status}" -eq 0 ]
  done
  run "$1" "${BAD}"
  [ "${status}" -ne 0 ]
}

@test "there are two callers to check" { [ "$(compgen -G "${CALLERS}/*.yml" | wc -l)" -eq 2 ]; }
@test "with: passes only declared inputs" { assert_rule passes_only_declared_inputs; }
@test "secrets: passes RELEASE_TOKEN, by name" { assert_rule passes_release_token_by_name; }
@test "a caller reads only declared outputs" { assert_rule reads_only_declared_outputs; }
@test "a job after the release runs only on release_created" { assert_rule publishes_only_a_release; }
@test "one caller publishes in the same workflow" {
  grep -l 'needs.release.outputs.release_created' "${CALLERS}"/*.yml
}

@test "a consumer pins the workflow by full SHA" {
  local caller
  for caller in "${CALLERS}"/*.yml; do pins_by_full_sha "${caller}"; done
  run ! pins_by_full_sha "${BAD}"
}

# By path, so the merge that changes release.yml is the run that exercises it.
@test "this repository calls its own release workflow by path" {
  [ "$(yq '.jobs.release.uses' "${SELF}")" = "./.github/workflows/release.yml" ]
}

@test "this repository releases on push to main, one run at a time" {
  [ "$(yq '.on | keys | join(",")' "${SELF}")" = "push" ]
  [ "$(yq '.on.push.branches | join(",")' "${SELF}")" = "main" ]
  [ "$(yq '.permissions | tag + length' "${SELF}")" = '!!map0' ]
  [ "$(yq '.concurrency["cancel-in-progress"]' "${SELF}")" = "false" ]
}
