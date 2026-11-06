#!/usr/bin/env bats
#
# The repositories calling pages.yml, as fixtures (CI-005, #32). Each rule runs
# against every caller and against a fixture that breaks it.

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/pages.yml"
CALLERS="${BATS_TEST_DIRNAME}/fixtures/pages-callers"
BAD="${BATS_TEST_DIRNAME}/fixtures/pages-caller-shape-bad.yml"

keys_of() { yq "$2 | keys | .[]" "$1" | sort; }

passes_only_declared_inputs() {
  [ -z "$(comm -23 <(keys_of "$1" '.jobs.pages.with // {}') <(keys_of "${WORKFLOW}" '.on.workflow_call.inputs'))" ]
}

passes_no_secret() { [ "$(yq '.jobs.pages | has("secrets")' "$1")" = "false" ]; }

pins_by_full_sha() {
  yq '.jobs.pages.uses' "$1" | grep -Eq '^mlorentedev/ci-workflows/\.github/workflows/pages\.yml@[0-9a-f]{40}$'
}

# The caller's permissions cap each called job, and a cap below a job's own
# request fails the run before any step.
grants_every_job_permission() {
  local scope level
  while read -r scope level; do
    [ "$(yq ".jobs.pages.permissions.\"${scope}\"" "$1")" = "${level}" ] || return 1
  done < <(yq '.jobs[].permissions | to_entries | .[] | .key + " " + .value' "${WORKFLOW}")
}

assert_rule() {
  local caller
  for caller in "${CALLERS}"/*.yml; do
    run "$1" "${caller}"
    [ "${status}" -eq 0 ]
  done
  run "$1" "${BAD}"
  [ "${status}" -ne 0 ]
}

@test "there are callers to check" { compgen -G "${CALLERS}/*.yml"; }
@test "with: passes only declared inputs" { assert_rule passes_only_declared_inputs; }
@test "no secret is passed" { assert_rule passes_no_secret; }
@test "the workflow is pinned by full SHA" { assert_rule pins_by_full_sha; }
@test "the caller grants what each job asks for" { assert_rule grants_every_job_permission; }
