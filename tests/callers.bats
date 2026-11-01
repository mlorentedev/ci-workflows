#!/usr/bin/env bats
#
# The repositories calling pr-agent.yml, as fixtures (TOOL-031, dotfiles#2893).
# Each rule runs against every caller and against a fixture that breaks it. A
# reusable workflow that drops an input breaks here before it breaks a consumer.

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/pr-agent.yml"
CALLERS="${BATS_TEST_DIRNAME}/fixtures/callers"
BAD="${BATS_TEST_DIRNAME}/fixtures/caller-shape-bad.yml"

keys_of() { yq "$2 | keys | .[]" "$1" | sort; }

required_of() {
  yq ".on.workflow_call.$1 | to_entries | .[] | select(.value.required == true) | .key" "${WORKFLOW}" | sort
}

passes_only_declared_inputs() {
  [ -z "$(comm -23 <(keys_of "$1" '.jobs.review.with') <(keys_of "${WORKFLOW}" '.on.workflow_call.inputs'))" ]
}

passes_every_required_input() {
  [ -z "$(comm -13 <(keys_of "$1" '.jobs.review.with') <(required_of inputs))" ]
}

passes_only_declared_secrets() {
  [ "$(yq '.jobs.review.secrets | tag' "$1")" = '!!map' ] &&
    [ -z "$(comm -23 <(keys_of "$1" '.jobs.review.secrets') <(keys_of "${WORKFLOW}" '.on.workflow_call.secrets'))" ]
}

passes_every_required_secret() {
  [ -z "$(comm -13 <(keys_of "$1" '.jobs.review.secrets') <(required_of secrets))" ]
}

pins_by_full_sha() {
  yq '.jobs.review.uses' "$1" | grep -Eq '^mlorentedev/ci-workflows/\.github/workflows/pr-agent\.yml@[0-9a-f]{40}$'
}

# The caller's permissions cap the called job, and a cap below its own request
# fails the run before any step.
grants_the_job_permissions() {
  local scope level
  while read -r scope level; do
    [ "$(yq ".jobs.review.permissions.\"${scope}\"" "$1")" = "${level}" ] || return 1
  done < <(yq '.jobs.review.permissions | to_entries | .[] | .key + " " + .value' "${WORKFLOW}")
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
@test "with: passes every required input" { assert_rule passes_every_required_input; }
@test "secrets: is a map of declared secrets" { assert_rule passes_only_declared_secrets; }
@test "secrets: passes every required secret" { assert_rule passes_every_required_secret; }
@test "the workflow is pinned by full SHA" { assert_rule pins_by_full_sha; }
@test "the caller grants what the job asks for" { assert_rule grants_the_job_permissions; }
