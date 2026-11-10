#!/usr/bin/env bats
#
# The shape of the fleet Renovate run and its preset (CI-003, #30). Each workflow
# rule runs against the workflow and against a fixture that breaks it, so a check
# that stopped matching fails here.

ROOT="${BATS_TEST_DIRNAME}/.."
WORKFLOW="${ROOT}/.github/workflows/renovate.yml"
BAD="${BATS_TEST_DIRNAME}/fixtures/renovate-shape-bad.yml"
PRESET="${ROOT}/renovate/default.json"
ENGINE="${ROOT}/renovate/engine.json"

# A missing token fails with its remedy before Renovate answers 401.
token_checked_first() {
  local first
  first=$(yq '.jobs.renovate.steps[0]' "$1")
  [ "$(yq '.env.HAS_RENOVATE_TOKEN' <<<"${first}")" = "\${{ secrets.RENOVATE_TOKEN != '' }}" ] &&
    yq '.run' <<<"${first}" | grep -q 'dotf secrets sync ci --repo .* RENOVATE_TOKEN' &&
    yq '.run' <<<"${first}" | grep -q 'exit 1'
}

renovate_uses_the_token() {
  [ "$(yq '.jobs.renovate.steps[] | select(.uses == "renovatebot/github-action@*") | .with.token' "$1")" = '${{ secrets.RENOVATE_TOKEN }}' ]
}

# The engine comes from renovate/engine.json, the pin the Gitea run reads too.
engine_from_the_pin_file() {
  [ "$(yq '.jobs.renovate.steps[] | select(.uses == "renovatebot/github-action@*") | .with["renovate-version"]' "$1")" = '${{ steps.engine.outputs.version }}' ] &&
    yq '.jobs.renovate.steps[] | select(.id == "engine") | .run' "$1" | grep -q 'renovate/engine.json'
}

# Only repositories that carry a renovate.json, and no onboarding PRs.
config_required() {
  [ "$(yq '.jobs.renovate.steps[] | select(.uses == "renovatebot/github-action@*") | .env.RENOVATE_REQUIRE_CONFIG' "$1")" = "required" ] &&
    [ "$(yq '.jobs.renovate.steps[] | select(.uses == "renovatebot/github-action@*") | .env.RENOVATE_ONBOARDING' "$1")" = "false" ]
}

every_action_pinned_by_sha() {
  [ "$(yq '[.jobs[].steps[] | select(has("uses")) | .uses | select(test("@[0-9a-f]{40}$") | not)] | length' "$1")" = "0" ]
}

asks_for_least() {
  [ "$(yq '.permissions | tag + length' "$1")" = '!!map0' ] &&
    [ "$(yq '.jobs.renovate.permissions | to_entries | map(.key + "=" + .value) | join(",")' "$1")" = "contents=read" ]
}

assert_rule() {
  run "$1" "${WORKFLOW}"
  [ "${status}" -eq 0 ]
  run "$1" "${BAD}"
  [ "${status}" -ne 0 ]
}

@test "a missing RENOVATE_TOKEN fails first, naming the remedy" { assert_rule token_checked_first; }
@test "Renovate authenticates with RENOVATE_TOKEN" { assert_rule renovate_uses_the_token; }
@test "the engine version comes from renovate/engine.json" { assert_rule engine_from_the_pin_file; }
@test "only repositories with a renovate.json run, with no onboarding" { assert_rule config_required; }
@test "every action is pinned by full SHA" { assert_rule every_action_pinned_by_sha; }
@test "GITHUB_TOKEN gets contents read and nothing else" { assert_rule asks_for_least; }

@test "the engine pin names an image and a version" {
  [ "$(jq -r '.image' "${ENGINE}")" = "ghcr.io/renovatebot/renovate" ]
  jq -er '.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")' "${ENGINE}"
}

# Gitea extends the same preset, so it may not carry a GitHub-only option.
@test "the preset carries no GitHub-only option" {
  run jq -e '[paths | map(tostring) | join(".")] | map(select(test("vulnerabilityAlerts|github-actions-only|platformAutomerge"))) | length == 0' "${PRESET}"
  [ "${status}" -eq 0 ]
}

@test "the preset never automerges" {
  [ "$(jq -r '.automerge' "${PRESET}")" = "false" ]
  [ "$(jq '[.. | objects | select(.automerge == true)] | length' "${PRESET}")" = "0" ]
}

# GitHub started the 01:17 UTC cron 6.5 hours late on 2026-11-09, after a
# 7-hour window had closed, and nothing opened (#48). The window is the whole day.
@test "the preset's schedule spans the whole of Monday" {
  [ "$(jq -c '.schedule' "${PRESET}")" = '["* * * * 1"]' ]
}

@test "one manager reads every dotf version default as one dependency" {
  local m
  m=$(jq -c '.customManagers[] | select(.depNameTemplate == "mlorentedev/dotfiles")' "${ROOT}/renovate.json")
  [ "$(jq -r '.datasourceTemplate' <<<"${m}")" = "github-releases" ]
  for f in .github/workflows/pr-agent.yml .github/actions/hygiene/action.yml; do
    grep -qE '^ +dotf[_-]version:$' "${ROOT}/${f}"
    jq -r '.managerFilePatterns[]' <<<"${m}" | grep -qxF "/^${f//./\\.}\$/"
  done
}
