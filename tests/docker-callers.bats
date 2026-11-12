#!/usr/bin/env bats
#
# The repositories that call docker-publish.yml or the docker-build composite,
# as fixtures (CI-010 AC4, #11). Each rule runs against every caller of its kind
# and against a fixture under bad/ that breaks it. Not in fixtures/callers/,
# which tests/callers.bats reads as pr-agent callers.

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/docker-publish.yml"
CALLERS="${BATS_TEST_DIRNAME}/fixtures/docker-callers"

publishers() { grep -l 'workflows/docker-publish.yml@' "${CALLERS}"/*.yml; }
builders() { grep -l 'actions/docker-build@' "${CALLERS}"/*.yml; }

keys_of() { yq "$2 | keys | .[]" "$1" | sort; }

passes_only_declared_inputs() {
  [ -z "$(comm -23 <(keys_of "$1" '.jobs.publish.with // {}') <(keys_of "${WORKFLOW}" '.on.workflow_call.inputs'))" ]
}

passes_every_required_input() {
  [ -z "$(comm -13 <(keys_of "$1" '.jobs.publish.with // {}') <(yq '.on.workflow_call.inputs | to_entries | .[] | select(.value.required) | .key' "${WORKFLOW}" | sort))" ]
}

passes_the_registry_secrets_by_name() {
  [ "$(yq '.jobs.publish.secrets | tag' "$1")" = "!!map" ] &&
    [ "$(keys_of "$1" '.jobs.publish.secrets' | xargs)" = "$(keys_of "${WORKFLOW}" '.on.workflow_call.secrets' | xargs)" ]
}

pins_the_workflow_by_full_sha() {
  yq '.jobs.publish.uses' "$1" | grep -Eq '^mlorentedev/ci-workflows/\.github/workflows/docker-publish\.yml@[0-9a-f]{40}$'
}

grants_every_job_permission() {
  local scope level
  while read -r scope level; do
    [ "$(yq ".jobs.publish.permissions.\"${scope}\"" "$1")" = "${level}" ] || return 1
  done < <(yq '.jobs[].permissions | to_entries | .[] | .key + " " + .value' "${WORKFLOW}" | sort -u)
}

# A build-then-run caller loads the image into the runner's docker, runs that
# image in a later step, and pins the composite by full SHA.
builds_then_runs() {
  local image
  image=$(yq '.. | select(has("uses") and (.uses | test("actions/docker-build@"))) | .with.image' "$1")
  yq '.. | select(has("uses") and (.uses | test("actions/docker-build@"))) | .uses' "$1" | grep -Eq '@[0-9a-f]{40}$' &&
    [ "$(yq '.. | select(has("uses") and (.uses | test("actions/docker-build@"))) | .with.load' "$1")" = "true" ] &&
    yq '.. | select(has("run")) | .run' "$1" | grep -q "docker run .*${image}"
}

assert_rule() {
  local kind=$1 rule=$2 bad=$3 caller
  for caller in $(${kind}); do
    run "${rule}" "${caller}"
    [ "${status}" -eq 0 ] || { echo "${caller##*/}: ${rule}"; return 1; }
  done
  run "${rule}" "${CALLERS}/bad/${bad}"
  [ "${status}" -ne 0 ]
}

@test "web and kubelab publish, and dotfiles builds then runs" {
  [ "$(publishers | xargs -n1 basename | sort | xargs)" = "kubelab.yml web.yml" ]
  [ "$(builders | xargs -n1 basename | xargs)" = "dotfiles.yml" ]
}
@test "with: passes only declared inputs" { assert_rule publishers passes_only_declared_inputs publish.yml; }
@test "with: passes every required input" { assert_rule publishers passes_every_required_input publish.yml; }
@test "the registry secrets are passed by name, never inherited" { assert_rule publishers passes_the_registry_secrets_by_name publish.yml; }
@test "the workflow is pinned by full SHA" { assert_rule publishers pins_the_workflow_by_full_sha publish.yml; }
@test "the caller grants what each job asks for" { assert_rule publishers grants_every_job_permission publish.yml; }
@test "a build-then-run caller loads, runs and pins the composite" { assert_rule builders builds_then_runs build.yml; }
