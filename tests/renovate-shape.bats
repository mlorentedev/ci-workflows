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

# A repository that aborts (the rate limit, a broken config) fails the job (#43).
errors_fail_the_run() {
  [ "$(yq '.jobs.renovate.steps[] | select(.uses == "renovatebot/github-action@*") | .env.RENOVATE_EXIT_CODE_FOR_ERRORS' "$1")" = "true" ]
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
@test "a repository that aborts fails the run" { assert_rule errors_fail_the_run; }
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

# The Actions prefix is `ci(deps):`, which release-please does not release. In a
# group that also held an application update, that title would hide the update
# from the release (#73), so Actions minor and patch updates group on their own,
# in a rule after the general group so it wins.
@test "GitHub Actions updates group apart from application updates" {
  local general actions
  general=$(jq '[.packageRules[] | .groupName == "minor and patch updates"] | index(true)' "${PRESET}")
  actions=$(jq '[.packageRules[] | (.matchManagers == ["github-actions"] and (.groupName // "") != "" and .groupName != "minor and patch updates")] | index(true)' "${PRESET}")
  [ "${general}" != "null" ] && [ "${actions}" != "null" ]
  [ "${actions}" -gt "${general}" ]
  [ "$(jq -c ".packageRules[${actions}].matchUpdateTypes" "${PRESET}")" = "$(jq -c ".packageRules[${general}].matchUpdateTypes" "${PRESET}")" ]
}

# PEP 621 has no lockfile-only update: a `>=` bound a new version satisfies gets
# no PR, so uv.lock went stale where Dependabot refreshed it (#73).
@test "PEP 621 lock files are refreshed by lock file maintenance" {
  [ "$(jq -r '.pep621.lockFileMaintenance.enabled' "${PRESET}")" = "true" ]
  # The engine's own lockFileMaintenance schedule is "before 4am on monday",
  # which replaces the preset's. A run that starts late (lesson-007) would skip
  # the refresh for a week, so the block repeats the preset's window.
  [ "$(jq -c '.pep621.lockFileMaintenance.schedule' "${PRESET}")" = "$(jq -c '.schedule' "${PRESET}")" ]
}

# One run a week: an hourly cap defers the overflow to next Monday (#73).
# prConcurrentLimit still bounds the open PRs.
@test "Poetry lock files get no refresh, which no release age could cover" {
  # Poetry has no exclude-newer, so a poetry.lock refresh would pull a release
  # published minutes earlier into a CI run with the repository's secrets (#86).
  [ "$(jq -r '.poetry.lockFileMaintenance.enabled // false' "${PRESET}")" = "false" ]
}

@test "no hourly PR limit, and a concurrent one" {
  [ "$(jq -r '.prHourlyLimit' "${PRESET}")" = "0" ]
  jq -e '.prConcurrentLimit > 0' "${PRESET}"
}

# A Renovate branch runs CI with the repository's secrets, where Dependabot's
# had none (#74). Packages whose install or tests execute code wait until a
# compromised release has usually been pulled.
@test "npm, PyPI and Go releases wait three days before they are proposed" {
  local r
  r=$(jq -c '.packageRules[] | select(.minimumReleaseAge != null)' "${PRESET}")
  [ "$(jq -r '.minimumReleaseAge' <<<"${r}")" = "3 days" ]
  [ "$(jq -c '.matchDatasources | sort' <<<"${r}")" = '["go","npm","pypi"]' ]
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

@test "CI runs the pinned engine on an aborting repository and expects a non-zero exit" {
  local run
  run=$(yq '.jobs.renovate-config.steps[] | select(.name == "Check the engine exits non-zero when a repository aborts") | .run' "${ROOT}/.github/workflows/lint.yml")
  grep -q 'renovate/engine.json' <<<"${run}"
  grep -q 'RENOVATE_EXIT_CODE_FOR_ERRORS=true' <<<"${run}"
  grep -q 'if \[ "${rc}" -eq 0 \]' <<<"${run}"
}
