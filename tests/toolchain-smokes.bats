#!/usr/bin/env bats
#
# The toolchain smokes in lint.yml run on Linux and macOS (spec CI-011, issue #71).

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/lint.yml"
NODE_FIXTURE="${BATS_TEST_DIRNAME}/fixtures/toolchains/node"
SMOKES="smoke-setup-node smoke-setup-python-poetry smoke-setup-python-uv smoke-setup-go-lint"
CONDITION="contains(fromJSON(needs.changes.outputs.areas), 'toolchains')"

job() { yq ".jobs.$1.$2" "${WORKFLOW}"; }

@test "every toolchain smoke runs on macOS and Linux" {
  local smoke
  for smoke in ${SMOKES}; do
    [ "$(job "${smoke}" 'strategy.matrix.os | sort | join(",")')" = "macos-latest,ubuntu-latest" ]
    [ "$(job "${smoke}" runs-on)" = '${{ matrix.os }}' ]
    [ "$(job "${smoke}" strategy.fail-fast)" = "false" ]
  done
}

@test "every macOS leg is behind the toolchains area and stays in gate's needs" {
  local smoke
  for smoke in ${SMOKES}; do
    [ "$(job "${smoke}" if)" = "${CONDITION}" ]
    [ "$(job "${smoke}" needs)" = "changes" ]
    yq '.jobs.gate.needs[]' "${WORKFLOW}" | grep -qx "${smoke}"
  done
}

@test "no workflow trigger runs the smokes outside pull requests and main" {
  [ "$(yq '.on | keys | sort | join(",")' "${WORKFLOW}")" = "pull_request,push" ]
}

@test "the smokes' run steps avoid bash 4 case expansions, which macOS bash 3.2 rejects" {
  local smoke
  for smoke in ${SMOKES}; do
    run bash -c "yq '.jobs.${smoke}.steps[].run | select(. != null)' '${WORKFLOW}' | grep -E '[,^]{1,2}\}'"
    [ "$status" -ne 0 ]
  done
}

@test "the node smoke caches Playwright: playwright input, Chromium install, browsers path checked" {
  local smoke=smoke-setup-node
  [ "$(yq ".jobs.${smoke}.steps[] | select(.id == \"node\") | .with.playwright" "${WORKFLOW}")" = "true" ]
  yq ".jobs.${smoke}.steps[].run | select(. != null)" "${WORKFLOW}" | grep -q 'npx playwright install chromium'
  yq ".jobs.${smoke}.steps[].run | select(. != null)" "${WORKFLOW}" | grep -q 'PLAYWRIGHT_BROWSERS_PATH'
  yq ".jobs.${smoke}.steps[].run | select(. != null)" "${WORKFLOW}" | grep -q 'chromium-'
}

@test "the node fixture pins @playwright/test exactly in its lockfile, for the Playwright cache key" {
  local version
  version=$(jq -r '.dependencies["@playwright/test"]' "${NODE_FIXTURE}/package.json")
  [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  [ "$(jq -r '.packages["node_modules/@playwright/test"].version' "${NODE_FIXTURE}/package-lock.json")" = "${version}" ]
}
