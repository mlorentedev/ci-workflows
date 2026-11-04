#!/usr/bin/env bats
#
# The gate action (ADR-001 decision 3, issue #9). Its step runs here the way a
# composite runs it, with NEEDS set as the caller's toJSON(needs) would set it.

ACTION="${BATS_TEST_DIRNAME}/../.github/actions/gate/action.yml"

setup() {
  yq '.runs.steps[] | select(.id == "gate") | .run' "${ACTION}" >"${BATS_TEST_TMPDIR}/step.sh"
}

run_gate() {
  NEEDS="$1" run bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/step.sh"
}

@test "the step runs under bash and reads needs from the input" {
  [ "$(yq '.runs.steps[] | select(.id == "gate") | .shell' "${ACTION}")" = "bash" ]
  [ "$(yq '.runs.steps[] | select(.id == "gate") | .env.NEEDS' "${ACTION}")" = '${{ inputs.needs }}' ]
  [ "$(yq '.inputs.needs.required' "${ACTION}")" = "true" ]
}

@test "passes when every need succeeded" {
  run_gate '{"lint":{"result":"success","outputs":{}},"test":{"result":"success","outputs":{}}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 needs"* ]]
}

@test "passes when a need was skipped by change detection" {
  run_gate '{"docs":{"result":"success"},"test":{"result":"skipped"}}'
  [ "$status" -eq 0 ]
}

@test "fails on a failed need and names it" {
  run_gate '{"lint":{"result":"success"},"test":{"result":"failure"}}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"test: failure"* ]]
  [[ "$output" != *"lint:"* ]]
}

@test "fails on a cancelled need and names it" {
  run_gate '{"test":{"result":"cancelled"}}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"test: cancelled"* ]]
}

@test "fails on every need that did not pass, not only the first" {
  run_gate '{"a":{"result":"failure"},"b":{"result":"cancelled"},"c":{"result":"success"}}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"a: failure"* ]]
  [[ "$output" == *"b: cancelled"* ]]
}

@test "fails when needs is empty, because a gate guarding nothing must not pass" {
  run_gate '{}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"no needs"* ]]
}

@test "fails when needs is not set" {
  run_gate ''
  [ "$status" -ne 0 ]
  [[ "$output" == *"no needs"* ]]
}

@test "fails when needs is not a JSON object" {
  run_gate 'not json'
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a JSON object"* ]]
}

@test "fails when a need carries no result" {
  run_gate '{"test":{"outputs":{}}}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"test: missing"* ]]
}
