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
# Since v0.2.0 every input has a default, so a caller passes only what it changes.
# A required input would break every caller pinned below it (AGENTS.md rule 5).
@test "no input is required" { [ -z "$(required_of inputs)" ]; }
# hive and kubelab omit pool, so they read the dotf pin's pool through this default.
@test "pool defaults to embedded" { [ "$(yq '.on.workflow_call.inputs.pool.default' "${WORKFLOW}")" = "embedded" ]; }
@test "secrets: is a map of declared secrets" { assert_rule passes_only_declared_secrets; }
@test "secrets: passes every required secret" { assert_rule passes_every_required_secret; }
@test "the workflow is pinned by full SHA" { assert_rule pins_by_full_sha; }
@test "the caller grants what the job asks for" { assert_rule grants_the_job_permissions; }

# This repository's own caller (#33) calls by path, so it is checked apart from
# the fixtures: the same contract, minus the SHA pin.
SELF="${BATS_TEST_DIRNAME}/../.github/workflows/review.yml"

calls_by_path_with_the_pool() {
  [ "$(yq '.jobs.review.uses' "$1")" = "./.github/workflows/pr-agent.yml" ] &&
    [ "$(yq '.jobs.review.with | has("dotf_version") or has("pool") or has("declared_model") or has("declared_fallback_models")' "$1")" = "false" ]
}

skips_release_branches() { [ "$(yq '.jobs.review.with.skip_branch_prefixes' "$1")" = "release-please--" ]; }

@test "this repository's caller keeps the contract" {
  local rule
  for rule in passes_only_declared_inputs passes_only_declared_secrets passes_every_required_secret grants_the_job_permissions; do
    "${rule}" "${SELF}"
  done
}
@test "this repository's caller uses the embedded pool by path" {
  calls_by_path_with_the_pool "${SELF}"
  ! calls_by_path_with_the_pool "${CALLERS}/hive.yml"
}
@test "this repository's caller skips release-please branches" {
  skips_release_branches "${SELF}"
  ! skips_release_branches "${BAD}"
}
