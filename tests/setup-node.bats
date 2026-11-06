#!/usr/bin/env bats
#
# The setup-node composite (spec CI-004, issue #10). actions/setup-node and
# actions/cache are not run here: the tests read their wiring from action.yml,
# and run the composite's own scripts the way a composite runs them.

ACTION="${BATS_TEST_DIRNAME}/../.github/actions/setup-node/action.yml"
LOCKS="${BATS_TEST_DIRNAME}/fixtures/setup-node"

step() { yq ".runs.steps[] | select(.id == \"$1\") | .$2" "${ACTION}"; }

setup() {
  export GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/output"
  : >"${GITHUB_OUTPUT}"
  step resolve run >"${BATS_TEST_TMPDIR}/resolve.sh"
  step playwright-version run >"${BATS_TEST_TMPDIR}/playwright-version.sh"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "${WORK}"
}

run_step() { run bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/$1.sh"; }

output_of() { sed -n "s/^$1=//p" "${GITHUB_OUTPUT}" | tail -1; }

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
  [ "$(step playwright with.path)" = "~/.cache/ms-playwright" ]
  local key
  key=$(step playwright with.key)
  [[ "${key}" == *'${{ runner.os }}'* ]]
  [[ "${key}" == *'${{ runner.arch }}'* ]]
  [[ "${key}" == *'${{ steps.playwright-version.outputs.version }}'* ]]
}

@test "the Playwright version is read from @playwright/test in the lockfile" {
  cp "${LOCKS}/playwright-test-lock.json" "${WORK}/package-lock.json"
  WORKDIR="${WORK}" run_step playwright-version
  [ "$status" -eq 0 ]
  [ "$(output_of version)" = "1.56.1" ]
}

@test "the Playwright version falls back to the playwright package" {
  cp "${LOCKS}/playwright-lock.json" "${WORK}/package-lock.json"
  WORKDIR="${WORK}" run_step playwright-version
  [ "$status" -eq 0 ]
  [ "$(output_of version)" = "1.55.0" ]
}

@test "a lockfile without Playwright fails rather than cache under an empty key" {
  cp "${LOCKS}/no-playwright-lock.json" "${WORK}/package-lock.json"
  WORKDIR="${WORK}" run_step playwright-version
  [ "$status" -ne 0 ]
  [[ "$output" == *"Playwright"* ]]
}

@test "a missing lockfile fails with its path" {
  WORKDIR="${WORK}" run_step playwright-version
  [ "$status" -ne 0 ]
  [[ "$output" == *"${WORK}/package-lock.json"* ]]
}
