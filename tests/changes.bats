#!/usr/bin/env bats
#
# The changes action (ADR-001 decision 4, issue #9). paths-filter itself is not
# run here: its `changes` output is what the areas step reads, so the tests set it
# the way the filter step would, and run the action's own scripts as a composite
# runs them.

ACTION="${BATS_TEST_DIRNAME}/../.github/actions/changes/action.yml"
FILTERS='docs:
  - "docs/**"
  - "**/*.md"
code:
  - "src/**"
ci:
  - ".github/**"'

step() { yq ".runs.steps[] | select(.id == \"$1\") | .$2" "${ACTION}"; }

setup() {
  export GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/output"
  : >"${GITHUB_OUTPUT}"
  step mode run >"${BATS_TEST_TMPDIR}/mode.sh"
  step areas run >"${BATS_TEST_TMPDIR}/areas.sh"
  # The action's own default, so the full-run tests below fail if it drops an event.
  FULL_RUN_EVENTS=$(yq '.inputs.full_run_events.default' "${ACTION}")
  export FULL_RUN_EVENTS
}

# Runs both scripts in order for one event, with CHANGED as paths-filter's output.
run_action() {
  local event="$1" changed="${2:-}" filters="${3:-${FILTERS}}"
  EVENT="${event}" bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/mode.sh" || return
  local full
  full=$(sed -n 's/^full=//p' "${GITHUB_OUTPUT}")
  FULL="${full}" CHANGED="${changed}" FILTERS="${filters}" \
    run bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/areas.sh"
}

output_of() { sed -n "s/^$1=//p" "${GITHUB_OUTPUT}" | tail -1; }

@test "the scripts run under bash with the inputs the composite maps" {
  [ "$(step mode shell)" = "bash" ]
  [ "$(step areas shell)" = "bash" ]
  [ "$(step mode env.EVENT)" = '${{ github.event_name }}' ]
  [ "$(step mode env.FULL_RUN_EVENTS)" = '${{ inputs.full_run_events }}' ]
  [ "$(step areas env.FILTERS)" = '${{ inputs.filters }}' ]
  [ "$(step areas env.CHANGED)" = '${{ steps.filter.outputs.changes }}' ]
  [ "$(step areas env.FULL)" = '${{ steps.mode.outputs.full }}' ]
}

@test "paths-filter is pinned by full SHA with its tag as a comment" {
  run grep -E '^\s+uses: dorny/paths-filter@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$' "${ACTION}"
  [ "$status" -eq 0 ]
}

@test "paths-filter runs only when the event is not a full run, with the caller's map" {
  [ "$(step filter if)" = "steps.mode.outputs.full != 'true'" ]
  [ "$(step filter with.filters)" = '${{ inputs.filters }}' ]
  [ "$(step filter with.token)" = '${{ inputs.token }}' ]
  [ "$(yq '.inputs.token.default' "${ACTION}")" = '${{ github.token }}' ]
}

@test "the action publishes areas and full from the areas step" {
  [ "$(yq '.outputs.areas.value' "${ACTION}")" = '${{ steps.areas.outputs.areas }}' ]
  [ "$(yq '.outputs.full.value' "${ACTION}")" = '${{ steps.areas.outputs.full }}' ]
}

@test "a docs-only pull request reports only docs" {
  run_action pull_request '["docs"]'
  [ "$status" -eq 0 ]
  [ "$(output_of areas)" = '["docs"]' ]
  [ "$(output_of full)" = "false" ]
}

@test "a code pull request reports its area" {
  run_action pull_request '["code","docs"]'
  [ "$status" -eq 0 ]
  [ "$(output_of areas)" = '["code","docs"]' ]
}

@test "a pull request touching no area reports an empty list" {
  run_action pull_request '[]'
  [ "$status" -eq 0 ]
  [ "$(output_of areas)" = '[]' ]
}

@test "a pull request whose filter gave no output fails rather than skip everything" {
  run_action pull_request ''
  [ "$status" -ne 0 ]
  [[ "$output" == *"paths-filter"* ]]
}

@test "a push reports every area as changed" {
  run_action push ''
  [ "$status" -eq 0 ]
  [ "$(output_of areas)" = '["docs","code","ci"]' ]
  [ "$(output_of full)" = "true" ]
}

@test "a schedule reports every area as changed" {
  run_action schedule ''
  [ "$(output_of areas)" = '["docs","code","ci"]' ]
  [ "$(output_of full)" = "true" ]
}

@test "a dispatch reports every area as changed" {
  run_action workflow_dispatch ''
  [ "$(output_of areas)" = '["docs","code","ci"]' ]
}

@test "full_run_events decides which events report every area" {
  FULL_RUN_EVENTS="schedule" run_action push '["code"]'
  [ "$(output_of areas)" = '["code"]' ]
  [ "$(output_of full)" = "false" ]
}

@test "an area map given as a path is read from the file" {
  printf '%s\n' "${FILTERS}" >"${BATS_TEST_TMPDIR}/filters.yml"
  run_action push '' "${BATS_TEST_TMPDIR}/filters.yml"
  [ "$status" -eq 0 ]
  [ "$(output_of areas)" = '["docs","code","ci"]' ]
}

@test "an area map that is not a mapping fails on a full run" {
  run_action push '' '- docs/**'
  [ "$status" -ne 0 ]
  [[ "$output" == *"mapping"* ]]
}

@test "a full run without yq fails rather than report no areas" {
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  for tool in bash sed cat; do ln -s "$(command -v "${tool}")" "${BATS_TEST_TMPDIR}/bin/${tool}"; done
  PATH="${BATS_TEST_TMPDIR}/bin" run_action push ''
  [ "$status" -ne 0 ]
  [[ "$output" == *"yq"* ]]
}
