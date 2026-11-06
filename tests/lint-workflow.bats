#!/usr/bin/env bats
#
# This repository's own CI. Branch protection requires `gate` alone, so a job
# missing from gate's needs fails without blocking a merge (dotfiles lesson 356).

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/lint.yml"

@test "gate needs every other job of lint.yml" {
  local jobs needs
  jobs=$(yq '.jobs | keys | .[] | select(. != "gate")' "${WORKFLOW}" | sort)
  needs=$(yq '.jobs.gate.needs[]' "${WORKFLOW}" | sort)
  [ -n "${jobs}" ]
  [ "${jobs}" = "${needs}" ]
}

@test "gate runs whatever its needs did" {
  [ "$(yq '.jobs.gate.if' "${WORKFLOW}")" = "always()" ]
}

@test "the setup-node smoke runs this checkout's composite on the toolchains area" {
  [ "$(yq '.jobs.smoke-setup-node.if' "${WORKFLOW}")" = "contains(fromJSON(needs.changes.outputs.areas), 'toolchains')" ]
  [ "$(yq '.jobs.smoke-setup-node.steps[] | select(.id == "node") | .uses' "${WORKFLOW}")" = "./.github/actions/setup-node" ]
  [ "$(yq '.jobs.smoke-setup-node.steps[] | select(.id == "node") | .with.working-directory' "${WORKFLOW}")" = "tests/fixtures/toolchains/node" ]
}

@test "the toolchains area covers every setup composite and its fixtures" {
  local filters
  filters=$(yq '.jobs.changes.steps[] | select(.id == "changes") | .with.filters' "${WORKFLOW}" | yq '.toolchains[]')
  [[ "${filters}" == *".github/actions/setup-*/**"* ]]
  [[ "${filters}" == *"tests/fixtures/toolchains/**"* ]]
}

@test "the smoke fixture pins its Node version and its dependencies" {
  local fixture="${BATS_TEST_DIRNAME}/fixtures/toolchains/node"
  [ -s "${fixture}/.nvmrc" ]
  [ "$(jq -r '.lockfileVersion' "${fixture}/package-lock.json")" = "3" ]
  [ "$(jq -r '.packages | length' "${fixture}/package-lock.json")" -ge 2 ]
}
