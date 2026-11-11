#!/usr/bin/env bats
#
# The setup-go-lint composite (spec CI-004, issue #10). actions/setup-go and the
# golangci-lint action are not run here: the tests read their wiring from
# action.yml, and run the composite's own script the way a composite runs it.

ACTION="${BATS_TEST_DIRNAME}/../.github/actions/setup-go-lint/action.yml"
WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/lint.yml"
FIXTURE="${BATS_TEST_DIRNAME}/fixtures/toolchains/go"

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

# A module that resolves: a go.mod with a go line and a go.sum.
module() {
  printf 'module example.com/fixture\n\ngo 1.25\n' >"${WORK}/go.mod"
  touch "${WORK}/go.sum"
}

# Shape (AC1)

@test "the inputs and their defaults" {
  [ "$(yq '.inputs.version.default' "${ACTION}")" = "" ]
  [ "$(yq '.inputs.version-file.default' "${ACTION}")" = "go.mod" ]
  [ "$(yq '.inputs.golangci-lint-version.default' "${ACTION}")" = "" ]
  [ "$(yq '.inputs.working-directory.default' "${ACTION}")" = "." ]
}

@test "the outputs map to setup-go and resolve" {
  [ "$(yq '.outputs.cache-hit.value' "${ACTION}")" = '${{ steps.setup.outputs.cache-hit }}' ]
  [ "$(yq '.outputs.go-version.value' "${ACTION}")" = '${{ steps.setup.outputs.go-version }}' ]
  [ "$(yq '.outputs.golangci-lint-version.value' "${ACTION}")" = '${{ steps.resolve.outputs.golangci-lint-version }}' ]
}

@test "the scripts run under bash" {
  [ "$(step resolve shell)" = "bash" ]
}

@test "every third-party action is pinned by full SHA with its tag as a comment" {
  local uses pinned
  uses=$(grep -cE '^\s+uses: [^.]' "${ACTION}")
  pinned=$(grep -cE '^\s+uses: [a-z0-9-]+/[a-z0-9-]+@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$' "${ACTION}")
  [ "${uses}" -eq 2 ]
  [ "${uses}" -eq "${pinned}" ]
}

@test "the steps run resolve, then setup-go, then the lint install" {
  [ "$(yq '.runs.steps[].id' "${ACTION}" | tr '\n' ' ')" = "resolve setup lint " ]
}

# setup-go v7.0.0 keys its cache on RUNNER_OS and process.arch
# (src/cache-restore.ts line 35), so the pin is what carries AC5 here: a new
# version is a new key format to read before the pin moves.
@test "setup-go is the v7.0.0 pin and caches on the resolved go.sum" {
  [ "$(step setup uses)" = "actions/setup-go@b7ad1dad31e06c5925ef5d2fc7ad053ef454303e" ]
  [ "$(step setup with.go-version)" = '${{ steps.resolve.outputs.go-version }}' ]
  [ "$(step setup with.go-version-file)" = '${{ steps.resolve.outputs.go-version-file }}' ]
  [ "$(step setup with.cache)" = "true" ]
  [ "$(step setup with.cache-dependency-path)" = '${{ steps.resolve.outputs.go-sum }}' ]
}

# The result cache reports findings a clean run does not (dotfiles lessons 353
# and 501): only the binary is installed, and nothing of the linter is cached.
@test "the lint step installs the binary only and never caches results" {
  [ "$(step lint uses | cut -d@ -f1)" = "golangci/golangci-lint-action" ]
  [ "$(step lint with.version)" = '${{ steps.resolve.outputs.golangci-lint-version }}' ]
  [ "$(step lint with.install-only)" = "true" ]
  [ "$(step lint with.skip-cache)" = "true" ]
  [ "$(step lint with.working-directory)" = '${{ inputs.working-directory }}' ]
}

@test "the resolve step reads the composite's inputs" {
  [ "$(step resolve env.VERSION)" = '${{ inputs.version }}' ]
  [ "$(step resolve env.VERSION_FILE)" = '${{ inputs.version-file }}' ]
  [ "$(step resolve env.LINT_VERSION)" = '${{ inputs.golangci-lint-version }}' ]
  [ "$(step resolve env.WORKDIR)" = '${{ inputs.working-directory }}' ]
}

# Version source (AC2)

@test "a Go version input is used as given, and the version file is left out" {
  module
  VERSION=1.24.3 VERSION_FILE=go.mod LINT_VERSION=v2.15.0 WORKDIR="${WORK}" run_resolve
  [ "$status" -eq 0 ]
  [ "$(output_of go-version)" = "1.24.3" ]
  [ "$(output_of go-version-file)" = "" ]
}

@test "without a Go version input, setup-go reads the version file" {
  module
  VERSION='' VERSION_FILE=go.mod LINT_VERSION=v2.15.0 WORKDIR="${WORK}" run_resolve
  [ "$status" -eq 0 ]
  [ "$(output_of go-version)" = "" ]
  [ "$(output_of go-version-file)" = "${WORK}/go.mod" ]
}

@test "a working directory of . gives paths without a ./ prefix" {
  cd "${WORK}"
  module
  VERSION='' VERSION_FILE=go.mod LINT_VERSION=v2.15.0 WORKDIR=. run_resolve
  [ "$status" -eq 0 ]
  [ "$(output_of go-version-file)" = "go.mod" ]
  [ "$(output_of go-sum)" = "go.sum" ]
}

# A caller forwarding an unset input passes "", which overrides the default.
@test "an empty working directory is read as ., not as the filesystem root" {
  cd "${WORK}"
  module
  VERSION='' VERSION_FILE=go.mod LINT_VERSION=v2.15.0 WORKDIR='' run_resolve
  [ "$status" -eq 0 ]
  [ "$(output_of go-version-file)" = "go.mod" ]
  [ "$(output_of go-sum)" = "go.sum" ]
}

@test "with neither a Go version nor the file, the step fails naming both" {
  touch "${WORK}/go.sum"
  VERSION='' VERSION_FILE=go.mod LINT_VERSION=v2.15.0 WORKDIR="${WORK}" run_resolve
  [ "$status" -ne 0 ]
  [[ "$output" == *"version"* ]]
  [[ "$output" == *"${WORK}/go.mod"* ]]
}

@test "a missing go.sum fails naming its path" {
  module
  rm "${WORK}/go.sum"
  VERSION=1.25 VERSION_FILE=go.mod LINT_VERSION=v2.15.0 WORKDIR="${WORK}" run_resolve
  [ "$status" -ne 0 ]
  [[ "$output" == *"${WORK}/go.sum"* ]]
}

@test "the go.sum path is published for the cache key" {
  module
  VERSION='' VERSION_FILE=go.mod LINT_VERSION=v2.15.0 WORKDIR="${WORK}" run_resolve
  [ "$(output_of go-sum)" = "${WORK}/go.sum" ]
}

@test "a golangci-lint version input is used, with a v added when missing" {
  module
  VERSION='' VERSION_FILE=go.mod LINT_VERSION=v2.15.0 WORKDIR="${WORK}" run_resolve
  [ "$(output_of golangci-lint-version)" = "v2.15.0" ]
  : >"${GITHUB_OUTPUT}"
  VERSION='' VERSION_FILE=go.mod LINT_VERSION=2.15 WORKDIR="${WORK}" run_resolve
  [ "$status" -eq 0 ]
  [ "$(output_of golangci-lint-version)" = "v2.15" ]
}

@test "without a golangci-lint input, go.mod's tool line gives the version" {
  module
  printf '\nrequire github.com/golangci/golangci-lint/v2 v2.14.1 // indirect\n\ntool github.com/golangci/golangci-lint/v2/cmd/golangci-lint\n' >>"${WORK}/go.mod"
  VERSION='' VERSION_FILE=go.mod LINT_VERSION='' WORKDIR="${WORK}" run_resolve
  [ "$status" -eq 0 ]
  [ "$(output_of golangci-lint-version)" = "v2.14.1" ]
}

@test "with no golangci-lint version, the step fails rather than install the latest" {
  module
  VERSION='' VERSION_FILE=go.mod LINT_VERSION='' WORKDIR="${WORK}" run_resolve
  [ "$status" -ne 0 ]
  [[ "$output" == *"golangci-lint-version"* ]]
  [[ "$output" == *"${WORK}/go.mod"* ]]
}

# This repository's smoke (AC3).

@test "the Go smoke runs this checkout's composite on the toolchains area" {
  local job=smoke-setup-go-lint
  [ "$(yq ".jobs.${job}.if" "${WORKFLOW}")" = "contains(fromJSON(needs.changes.outputs.areas), 'toolchains')" ]
  [ "$(yq ".jobs.${job}.steps[] | select(.id == \"go\") | .uses" "${WORKFLOW}")" = "./.github/actions/setup-go-lint" ]
  [ "$(yq ".jobs.${job}.steps[] | select(.id == \"go\") | .with.working-directory" "${WORKFLOW}")" = "tests/fixtures/toolchains/go" ]
  yq ".jobs.${job}.steps[].run" "${WORKFLOW}" | grep -q 'go build ./...'
  yq ".jobs.${job}.steps[].run" "${WORKFLOW}" | grep -q 'golangci-lint run'
  yq '.jobs.gate.needs[]' "${WORKFLOW}" | grep -qx "${job}"
}

@test "the Go fixture has a go line and a go.sum" {
  grep -qE '^go [0-9]+\.[0-9]+' "${FIXTURE}/go.mod"
  [ -s "${FIXTURE}/go.sum" ]
}
