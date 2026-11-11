#!/usr/bin/env bats
#
# The setup-node composite (spec CI-004, issue #10). actions/setup-node and
# actions/cache are not run here: the tests read their wiring from action.yml,
# and run the composite's own scripts the way a composite runs them.

ACTION="${BATS_TEST_DIRNAME}/../.github/actions/setup-node/action.yml"
WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/lint.yml"
FIXTURE="${BATS_TEST_DIRNAME}/fixtures/toolchains/node"

step() { yq ".runs.steps[] | select(.id == \"$1\") | .$2" "${ACTION}"; }

setup() {
  export GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/output"
  : >"${GITHUB_OUTPUT}"
  export GITHUB_ENV="${BATS_TEST_TMPDIR}/env"
  : >"${GITHUB_ENV}"
  unset PLAYWRIGHT_BROWSERS_PATH
  step resolve run >"${BATS_TEST_TMPDIR}/resolve.sh"
  step playwright-version run >"${BATS_TEST_TMPDIR}/playwright-version.sh"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "${WORK}"
}

run_step() { run bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/$1.sh"; }

output_of() { sed -n "s/^$1=//p" "${GITHUB_OUTPUT}" | tail -1; }

# A package-lock.json in the work directory holding the given packages.
lock_with() {
  local pkgs='{"": {"name": "fixture"}}' name version
  while [ $# -gt 0 ]; do
    name="$1" version="$2"
    shift 2
    pkgs=$(jq -c --arg k "node_modules/${name}" --arg v "${version}" '. + {($k): {version: $v}}' <<<"${pkgs}")
  done
  jq -n --argjson p "${pkgs}" '{name: "fixture", lockfileVersion: 3, packages: $p}' >"${WORK}/package-lock.json"
}

# Shape (AC1)

@test "the inputs and their defaults" {
  [ "$(yq '.inputs.version.default' "${ACTION}")" = "" ]
  [ "$(yq '.inputs.version-file.default' "${ACTION}")" = ".nvmrc" ]
  [ "$(yq '.inputs.working-directory.default' "${ACTION}")" = "." ]
  [ "$(yq '.inputs.playwright.default' "${ACTION}")" = "false" ]
}

@test "the outputs map to the setup and playwright steps" {
  [ "$(yq '.outputs.cache-hit.value' "${ACTION}")" = '${{ steps.setup.outputs.cache-hit }}' ]
  [ "$(yq '.outputs.cache-primary-key.value' "${ACTION}")" = '${{ steps.setup.outputs.cache-primary-key }}' ]
  [ "$(yq '.outputs.playwright-cache-hit.value' "${ACTION}")" = '${{ steps.playwright.outputs.cache-hit }}' ]
}

@test "the scripts run under bash" {
  [ "$(step resolve shell)" = "bash" ]
  [ "$(step playwright-version shell)" = "bash" ]
}

@test "every third-party action is pinned by full SHA with its tag as a comment" {
  local uses pinned
  uses=$(grep -cE '^\s+uses: [^.]' "${ACTION}")
  pinned=$(grep -cE '^\s+uses: [a-z0-9-]+/[a-z0-9-]+@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$' "${ACTION}")
  [ "${uses}" -ge 2 ]
  [ "${uses}" -eq "${pinned}" ]
}

@test "setup-node installs the resolved version with the npm cache of the working directory" {
  [ "$(step setup uses | cut -d@ -f1)" = "actions/setup-node" ]
  [ "$(step setup with.node-version)" = '${{ steps.resolve.outputs.version }}' ]
  [ "$(step setup with.node-version-file)" = '${{ steps.resolve.outputs.file }}' ]
  [ "$(step setup with.cache)" = "npm" ]
  [ "$(step setup with.cache-dependency-path)" = '${{ inputs.working-directory }}/package-lock.json' ]
}

# Version source (AC2)

@test "a version input is installed as given" {
  VERSION=22.11.0 VERSION_FILE=.nvmrc WORKDIR="${WORK}" run_step resolve
  [ "$status" -eq 0 ]
  [ "$(output_of version)" = "22.11.0" ]
  [ "$(output_of file)" = "" ]
}

@test "the version input wins over a present version file" {
  echo 20 >"${WORK}/.nvmrc"
  VERSION=22 VERSION_FILE=.nvmrc WORKDIR="${WORK}" run_step resolve
  [ "$(output_of version)" = "22" ]
  [ "$(output_of file)" = "" ]
}

@test "without a version input, the version file in the working directory is used" {
  echo 22 >"${WORK}/.nvmrc"
  VERSION='' VERSION_FILE=.nvmrc WORKDIR="${WORK}" run_step resolve
  [ "$status" -eq 0 ]
  [ "$(output_of version)" = "" ]
  [ "$(output_of file)" = "${WORK}/.nvmrc" ]
}

@test "with neither a version nor the file, the step fails naming both" {
  VERSION='' VERSION_FILE=.nvmrc WORKDIR="${WORK}" run_step resolve
  [ "$status" -ne 0 ]
  [[ "$output" == *"version"* ]]
  [[ "$output" == *"${WORK}/.nvmrc"* ]]
}

@test "the resolve step reads the composite's inputs" {
  [ "$(step resolve env.VERSION)" = '${{ inputs.version }}' ]
  [ "$(step resolve env.VERSION_FILE)" = '${{ inputs.version-file }}' ]
  [ "$(step resolve env.WORKDIR)" = '${{ inputs.working-directory }}' ]
}

# Playwright (AC2, AC5)

@test "the Playwright steps run only when the caller asks for them" {
  [ "$(step playwright-version if)" = "inputs.playwright == 'true'" ]
  [ "$(step playwright if)" = "inputs.playwright == 'true'" ]
}

@test "the Playwright cache key holds the platform, the arch and the Playwright version" {
  [ "$(step playwright uses | cut -d@ -f1)" = "actions/cache" ]
  [ "$(step playwright with.path)" = '${{ steps.playwright-version.outputs.path }}' ]
  local key
  key=$(step playwright with.key)
  [[ "${key}" == *'${{ runner.os }}'* ]]
  [[ "${key}" == *'${{ runner.arch }}'* ]]
  [[ "${key}" == *'${{ steps.playwright-version.outputs.version }}'* ]]
}

@test "the Playwright version is read from @playwright/test in the lockfile" {
  lock_with @playwright/test 1.56.1 playwright 1.56.1
  WORKDIR="${WORK}" run_step playwright-version
  [ "$status" -eq 0 ]
  [ "$(output_of version)" = "1.56.1" ]
}

@test "the Playwright version falls back to the playwright package" {
  lock_with playwright 1.55.0
  WORKDIR="${WORK}" run_step playwright-version
  [ "$status" -eq 0 ]
  [ "$(output_of version)" = "1.55.0" ]
}

@test "a lockfile without Playwright fails rather than cache under an empty key" {
  lock_with left-pad 1.3.0
  WORKDIR="${WORK}" run_step playwright-version
  [ "$status" -ne 0 ]
  [[ "$output" == *"Playwright"* ]]
}

# Playwright's own default is per-OS (~/Library/Caches on macOS), so the composite
# names one path, caches it, and hands it to the caller's later steps (#67).
@test "the browsers path defaults to ~/.cache/ms-playwright and reaches the caller's steps" {
  lock_with @playwright/test 1.56.1
  HOME=/home/runner WORKDIR="${WORK}" run_step playwright-version
  [ "$status" -eq 0 ]
  [ "$(output_of path)" = "/home/runner/.cache/ms-playwright" ]
  grep -qx 'PLAYWRIGHT_BROWSERS_PATH=/home/runner/.cache/ms-playwright' "${GITHUB_ENV}"
}

@test "a caller's PLAYWRIGHT_BROWSERS_PATH is the path cached" {
  lock_with @playwright/test 1.56.1
  PLAYWRIGHT_BROWSERS_PATH=/opt/browsers WORKDIR="${WORK}" run_step playwright-version
  [ "$status" -eq 0 ]
  [ "$(output_of path)" = "/opt/browsers" ]
  grep -qx 'PLAYWRIGHT_BROWSERS_PATH=/opt/browsers' "${GITHUB_ENV}"
}

@test "PLAYWRIGHT_BROWSERS_PATH=0 fails, since the browsers would sit in node_modules" {
  lock_with @playwright/test 1.56.1
  PLAYWRIGHT_BROWSERS_PATH=0 WORKDIR="${WORK}" run_step playwright-version
  [ "$status" -ne 0 ]
  [[ "$output" == *"PLAYWRIGHT_BROWSERS_PATH=0"* ]]
}

@test "on Windows the default path is handed over in Windows form" {
  lock_with @playwright/test 1.56.1
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  cat >"${BATS_TEST_TMPDIR}/bin/cygpath" <<'STUB'
#!/bin/sh
[ "$1" = -w ] && printf '%s\n' 'C:\Users\runneradmin\.cache\ms-playwright'
STUB
  chmod +x "${BATS_TEST_TMPDIR}/bin/cygpath"
  PATH="${BATS_TEST_TMPDIR}/bin:${PATH}" HOME=/c/Users/runneradmin WORKDIR="${WORK}" run_step playwright-version
  [ "$status" -eq 0 ]
  [ "$(output_of path)" = 'C:\Users\runneradmin\.cache\ms-playwright' ]
}

@test "a missing lockfile fails with its path" {
  WORKDIR="${WORK}" run_step playwright-version
  [ "$status" -ne 0 ]
  [[ "$output" == *"${WORK}/package-lock.json"* ]]
}

# This repository's smoke (AC3). Branch protection requires `gate` alone, so a
# job missing from gate's needs fails without blocking a merge (dotfiles lesson 356).

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
  [ -s "${FIXTURE}/.nvmrc" ]
  [ "$(jq -r '.lockfileVersion' "${FIXTURE}/package-lock.json")" = "3" ]
  [ "$(jq -r '.packages | length' "${FIXTURE}/package-lock.json")" -ge 2 ]
}

@test "the fixture's lockfile matches its package.json" {
  [ "$(jq -cS '.dependencies' "${FIXTURE}/package.json")" = "$(jq -cS '.packages[""].dependencies' "${FIXTURE}/package-lock.json")" ]
}

@test "the spec's feature list parses and gives every feature a verification" {
  run jq -e 'all(.[]; (.verification | type) == "string" and (.verification | length) > 0)' \
    "${BATS_TEST_DIRNAME}/../specs/archive/CI-004-toolchain-setup/features.json"
  [ "$status" -eq 0 ]
}
