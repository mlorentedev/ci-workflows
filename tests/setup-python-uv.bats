#!/usr/bin/env bats
#
# The setup-python-uv composite (spec CI-004, issue #10). astral-sh/setup-uv is
# not run here: the tests read its wiring from action.yml, and run the
# composite's own script the way a composite runs it.

ACTION="${BATS_TEST_DIRNAME}/../.github/actions/setup-python-uv/action.yml"
WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/lint.yml"
FIXTURE="${BATS_TEST_DIRNAME}/fixtures/toolchains/uv"

step() { yq ".runs.steps[] | select(.id == \"$1\") | .$2" "${ACTION}"; }

setup() {
  export GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/output"
  : >"${GITHUB_OUTPUT}"
  step resolve run >"${BATS_TEST_TMPDIR}/resolve.sh"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "${WORK}"
}

run_resolve() { run bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/resolve.sh"; }

output_of() { sed -n "s/^$1=//p" "${GITHUB_OUTPUT}" | tail -1; }

# Shape (AC1)

@test "the inputs and their defaults" {
  [ "$(yq '.inputs.version.default' "${ACTION}")" = "" ]
  [ "$(yq '.inputs.version-file.default' "${ACTION}")" = ".python-version" ]
  [ "$(yq '.inputs.uv-version.default' "${ACTION}")" = "" ]
  [ "$(yq '.inputs.working-directory.default' "${ACTION}")" = "." ]
}

@test "the outputs map to setup-uv" {
  [ "$(yq '.outputs.cache-hit.value' "${ACTION}")" = '${{ steps.setup.outputs.cache-hit }}' ]
  [ "$(yq '.outputs.cache-primary-key.value' "${ACTION}")" = '${{ steps.setup.outputs.cache-key }}' ]
  [ "$(yq '.outputs.python-cache-hit.value' "${ACTION}")" = '${{ steps.setup.outputs.python-cache-hit }}' ]
  [ "$(yq '.outputs.uv-version.value' "${ACTION}")" = '${{ steps.setup.outputs.uv-version }}' ]
}

@test "the scripts run under bash" {
  [ "$(step resolve shell)" = "bash" ]
}

@test "every third-party action is pinned by full SHA with its tag as a comment" {
  local uses pinned
  uses=$(grep -cE '^\s+uses: [^.]' "${ACTION}")
  pinned=$(grep -cE '^\s+uses: [a-z0-9-]+/[a-z0-9-]+@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$' "${ACTION}")
  [ "${uses}" -ge 1 ]
  [ "${uses}" -eq "${pinned}" ]
}

@test "setup-uv gets the resolved Python and caches on the working directory's uv.lock" {
  [ "$(step setup uses | cut -d@ -f1)" = "astral-sh/setup-uv" ]
  [ "$(step setup with.python-version)" = '${{ steps.resolve.outputs.python-version }}' ]
  [ "$(step setup with.version)" = '${{ inputs.uv-version }}' ]
  [ "$(step setup with.working-directory)" = '${{ inputs.working-directory }}' ]
  [ "$(step setup with.enable-cache)" = "true" ]
  [ "$(step setup with.cache-dependency-glob)" = "uv.lock" ]
  [ "$(step setup with.cache-python)" = "true" ]
}

@test "the steps run resolve, then setup-uv" {
  [ "$(yq '.runs.steps[].id' "${ACTION}" | tr '\n' ' ')" = "resolve setup " ]
}

# Version source (AC2)

@test "a version input is used as given" {
  touch "${WORK}/uv.lock"
  VERSION=3.12.7 VERSION_FILE=.python-version WORKDIR="${WORK}" run_resolve
  [ "$status" -eq 0 ]
  [ "$(output_of python-version)" = "3.12.7" ]
}

@test "the version input wins over a present version file" {
  touch "${WORK}/uv.lock"
  echo 3.12 >"${WORK}/.python-version"
  VERSION=3.13 VERSION_FILE=.python-version WORKDIR="${WORK}" run_resolve
  [ "$(output_of python-version)" = "3.13" ]
}

@test "without a version input, the version file's first line is used, trimmed" {
  touch "${WORK}/uv.lock"
  printf '  3.13 \n3.12\n' >"${WORK}/.python-version"
  VERSION='' VERSION_FILE=.python-version WORKDIR="${WORK}" run_resolve
  [ "$status" -eq 0 ]
  [ "$(output_of python-version)" = "3.13" ]
}

@test "a CRLF version file gives the version without its carriage return" {
  touch "${WORK}/uv.lock"
  printf ' 3.13 \r\n' >"${WORK}/.python-version"
  VERSION='' VERSION_FILE=.python-version WORKDIR="${WORK}" run_resolve
  [ "$status" -eq 0 ]
  [ "$(output_of python-version)" = "3.13" ]
}

@test "with neither a version nor the file, the step fails naming both" {
  touch "${WORK}/uv.lock"
  VERSION='' VERSION_FILE=.python-version WORKDIR="${WORK}" run_resolve
  [ "$status" -ne 0 ]
  [[ "$output" == *"version"* ]]
  [[ "$output" == *"${WORK}/.python-version"* ]]
}

@test "an empty version file fails rather than pass an empty version" {
  touch "${WORK}/uv.lock"
  : >"${WORK}/.python-version"
  VERSION='' VERSION_FILE=.python-version WORKDIR="${WORK}" run_resolve
  [ "$status" -ne 0 ]
  [[ "$output" == *"${WORK}/.python-version"* ]]
}

@test "a missing uv.lock fails naming its path, rather than share a key" {
  VERSION=3.13 VERSION_FILE=.python-version WORKDIR="${WORK}" run_resolve
  [ "$status" -ne 0 ]
  [[ "$output" == *"${WORK}/uv.lock"* ]]
}

@test "the resolve step reads the composite's inputs" {
  [ "$(step resolve env.VERSION)" = '${{ inputs.version }}' ]
  [ "$(step resolve env.VERSION_FILE)" = '${{ inputs.version-file }}' ]
  [ "$(step resolve env.WORKDIR)" = '${{ inputs.working-directory }}' ]
}

# This repository's smoke (AC3, AC5).

@test "the uv smoke runs this checkout's composite on the toolchains area" {
  local job=smoke-setup-python-uv
  [ "$(yq ".jobs.${job}.if" "${WORKFLOW}")" = "contains(fromJSON(needs.changes.outputs.areas), 'toolchains')" ]
  [ "$(yq ".jobs.${job}.steps[] | select(.id == \"uv\") | .uses" "${WORKFLOW}")" = "./.github/actions/setup-python-uv" ]
  [ "$(yq ".jobs.${job}.steps[] | select(.id == \"uv\") | .with.working-directory" "${WORKFLOW}")" = "tests/fixtures/toolchains/uv" ]
  yq ".jobs.${job}.steps[].run" "${WORKFLOW}" | grep -q 'uv sync --locked'
}

# The smoke's key check, run with the runner's variables. The expected names are
# setup-uv's own (src/utils/platforms.ts maps x64 to x86_64, linux to
# unknown-linux-gnu, arm64 to aarch64, darwin to apple-darwin).
key_check() {
  yq '.jobs.smoke-setup-python-uv.steps[] | select(.name == "Report the cache") | .run' "${WORKFLOW}" >"${BATS_TEST_TMPDIR}/key.sh"
  RUNNER_ARCH="$1" RUNNER_OS="$2" KEY="$3" HIT=true PYTHON_HIT=true \
    run bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/key.sh"
}

@test "the uv smoke accepts a key naming the runner's platform and arch" {
  key_check X64 Linux setup-uv-2-x86_64-unknown-linux-gnu-ubuntu-24.04-3.13-py-abc
  [ "$status" -eq 0 ]
  key_check ARM64 macOS setup-uv-2-aarch64-apple-darwin-macos-15-3.13-py-abc
  [ "$status" -eq 0 ]
}

@test "the uv smoke fails a key without the platform and the arch" {
  key_check X64 Linux setup-uv-2-unknown-linux-gnu-ubuntu-24.04-3.13-py-abc
  [ "$status" -ne 0 ]
  key_check X64 Linux setup-uv-2-aarch64-unknown-linux-gnu-ubuntu-24.04-3.13-py-abc
  [ "$status" -ne 0 ]
  key_check X64 Linux setup-uv-2-x86_64-apple-darwin-macos-15-3.13-py-abc
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not start with setup-uv-2-x86_64-unknown-linux-gnu-"* ]]
}

@test "the uv fixture pins its Python version and has a lock" {
  [ -s "${FIXTURE}/.python-version" ]
  grep -q '^\[\[package\]\]' "${FIXTURE}/uv.lock"
}
