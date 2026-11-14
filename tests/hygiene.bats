#!/usr/bin/env bats
#
# The hygiene composite (spec CI-005, issue #31). The steps run here the way a
# composite runs them, with stubs on PATH: `curl` serves a release from a local
# directory and `dotf` records its arguments. The real dotf runs in lint.yml's
# smoke-hygiene job, against this repository and the lesson fixtures.

bats_require_minimum_version 1.5.0

ACTION="${BATS_TEST_DIRNAME}/../.github/actions/hygiene/action.yml"
WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/lint.yml"

step() { yq ".runs.steps[] | select(.id == \"$1\") | .$2" "${ACTION}"; }

setup() {
  export GITHUB_PATH="${BATS_TEST_TMPDIR}/path"
  export RUNNER_TEMP="${BATS_TEST_TMPDIR}/runner"
  export RUNNER_OS=Linux RUNNER_ARCH=X64
  export DOTF_VERSION=9.9.9
  export DOTF_BASE_URL="https://example.invalid/releases"
  export RELEASE="${BATS_TEST_TMPDIR}/release/v${DOTF_VERSION}"
  : >"${GITHUB_PATH}"
  mkdir -p "${RUNNER_TEMP}" "${RELEASE}" "${BATS_TEST_TMPDIR}/stubs"
  step install run >"${BATS_TEST_TMPDIR}/install.sh"
  step lessons run >"${BATS_TEST_TMPDIR}/lessons.sh"
  step pinned-actions run >"${BATS_TEST_TMPDIR}/pinned-actions.sh"

  # curl -fsSL --retry 3 -o <file> <url>: copy the URL's basename out of RELEASE.
  cat >"${BATS_TEST_TMPDIR}/stubs/curl" <<'STUB'
#!/usr/bin/env bash
out="" url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    --retry) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
echo "${url}" >>"${BATS_TEST_TMPDIR}/curl.log"
cp "${RELEASE}/${url##*/}" "${out}" 2>/dev/null || exit 22
STUB
  chmod +x "${BATS_TEST_TMPDIR}/stubs/curl"
  export PATH="${BATS_TEST_TMPDIR}/stubs:${PATH}"
}

run_step() { run bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/$1.sh"; }

# A release holding a dotf for the platform, and its checksums.txt.
publish() {
  local platform="$1" tarball pack="${BATS_TEST_TMPDIR}/pack"
  tarball="dotf_${DOTF_VERSION}_${platform}.tar.gz"
  mkdir -p "${pack}"
  printf '#!/bin/sh\necho "dotf %s"\n' "${DOTF_VERSION}" >"${pack}/dotf"
  chmod +x "${pack}/dotf"
  tar -czf "${RELEASE}/${tarball}" -C "${pack}" dotf
  (cd "${RELEASE}" && sha256sum "${tarball}" >checksums.txt)
}

# Shape (AC1)

@test "the inputs and their defaults" {
  [[ "$(yq '.inputs.dotf-version.default' "${ACTION}")" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  [ "$(yq '.inputs.lessons.default' "${ACTION}")" = "true" ]
  [ "$(yq '.inputs.lessons-dir.default' "${ACTION}")" = "docs/lessons" ]
  [ "$(yq '.inputs.pinned-actions.default' "${ACTION}")" = "true" ]
}

@test "no input names a check the composite does not run" {
  [ "$(yq '.inputs | keys | join(",")' "${ACTION}")" = "dotf-version,lessons,lessons-dir,pinned-actions" ]
}

@test "every step is a bash run step: no action, so nothing GitHub-only" {
  [ "$(yq '[.runs.steps[] | select(has("uses"))] | length' "${ACTION}")" = "0" ]
  [ "$(yq '[.runs.steps[] | select(.shell != "bash")] | length' "${ACTION}")" = "0" ]
  run ! grep -qE '\bgh |GH_TOKEN|github\.token' "${ACTION}"
}

@test "the lessons step runs only when lessons is 'true'" {
  [ "$(step lessons if)" = "inputs.lessons == 'true'" ]
}

@test "the pinned-actions step runs only when pinned-actions is 'true'" {
  [ "$(step pinned-actions if)" = "inputs.pinned-actions == 'true'" ]
}

# Install (AC1)

@test "install fetches the pinned release, checks it, and puts dotf on the path" {
  publish linux_amd64
  run_step install
  [ "$status" -eq 0 ]
  grep -qx "${DOTF_BASE_URL}/v${DOTF_VERSION}/dotf_${DOTF_VERSION}_linux_amd64.tar.gz" "${BATS_TEST_TMPDIR}/curl.log"
  bin="$(cat "${GITHUB_PATH}")"
  [ "$("${bin}/dotf")" = "dotf ${DOTF_VERSION}" ]
}

@test "install picks the arm64 build on an ARM64 runner" {
  export RUNNER_ARCH=ARM64
  publish linux_arm64
  run_step install
  [ "$status" -eq 0 ]
  grep -q "dotf_${DOTF_VERSION}_linux_arm64.tar.gz$" "${BATS_TEST_TMPDIR}/curl.log"
}

@test "install fails on an archive that does not match checksums.txt" {
  publish linux_amd64
  echo tampered >>"${RELEASE}/dotf_${DOTF_VERSION}_linux_amd64.tar.gz"
  run_step install
  [ "$status" -ne 0 ]
  [ ! -s "${GITHUB_PATH}" ]
}

@test "install fails when checksums.txt does not list the archive" {
  publish linux_amd64
  : >"${RELEASE}/checksums.txt"
  run_step install
  [ "$status" -ne 0 ]
  [[ "$output" == *"lists no dotf_${DOTF_VERSION}_linux_amd64.tar.gz"* ]]
}

@test "install fails when the release does not exist" {
  run_step install
  [ "$status" -ne 0 ]
  [ ! -s "${GITHUB_PATH}" ]
}

@test "install refuses a runner with no dotf build, naming it" {
  export RUNNER_OS=Windows
  publish linux_amd64
  run_step install
  [ "$status" -ne 0 ]
  [[ "$output" == *"no dotf build for Windows/X64"* ]]
}

# Lessons (AC2)

@test "the lessons step checks the lessons directory under the workspace" {
  printf '#!/bin/sh\necho "$@" >"%s/dotf.log"\n' "${BATS_TEST_TMPDIR}" >"${BATS_TEST_TMPDIR}/stubs/dotf"
  chmod +x "${BATS_TEST_TMPDIR}/stubs/dotf"
  GITHUB_WORKSPACE=/ws LESSONS_DIR=docs/lessons run_step lessons
  [ "$status" -eq 0 ]
  [ "$(cat "${BATS_TEST_TMPDIR}/dotf.log")" = "lessons fmt --check --dir /ws/docs/lessons" ]
}

@test "the lessons step fails when dotf does" {
  printf '#!/bin/sh\necho "lesson number 001 is used twice" >&2\nexit 1\n' >"${BATS_TEST_TMPDIR}/stubs/dotf"
  chmod +x "${BATS_TEST_TMPDIR}/stubs/dotf"
  GITHUB_WORKSPACE=/ws LESSONS_DIR=docs/lessons run_step lessons
  [ "$status" -eq 1 ]
  [[ "$output" == *"used twice"* ]]
  grep -q "used twice" "${RUNNER_TEMP}/hygiene-lessons.txt"
}

# Pinned actions (AC3)

@test "the pinned-actions step runs only the SHA-pin rule over the workspace" {
  printf '#!/bin/sh\necho "$@" >"%s/dotf.log"\n' "${BATS_TEST_TMPDIR}" >"${BATS_TEST_TMPDIR}/stubs/dotf"
  chmod +x "${BATS_TEST_TMPDIR}/stubs/dotf"
  GITHUB_WORKSPACE=/ws run_step pinned-actions
  [ "$status" -eq 0 ]
  [ "$(cat "${BATS_TEST_TMPDIR}/dotf.log")" = "lint fleet --dir /ws --rule fleet/sha-pin" ]
}

@test "the pinned-actions step fails when dotf does, and keeps the report" {
  printf '#!/bin/sh\necho "ci.yml:6: fleet/sha-pin: actions/checkout@v4 is not pinned" >&2\nexit 1\n' >"${BATS_TEST_TMPDIR}/stubs/dotf"
  chmod +x "${BATS_TEST_TMPDIR}/stubs/dotf"
  GITHUB_WORKSPACE=/ws run_step pinned-actions
  [ "$status" -eq 1 ]
  [[ "$output" == *"ci.yml:6: fleet/sha-pin"* ]]
  grep -q "ci.yml:6: fleet/sha-pin" "${RUNNER_TEMP}/hygiene-pinned-actions.txt"
}

# Smoke wiring (AC2, AC3)

@test "smoke-hygiene expects the duplicate-number fixture to fail" {
  local job=".jobs.smoke-hygiene"
  [ "$(yq "${job}.steps[] | select(.id == \"duplicate\") | .continue-on-error" "${WORKFLOW}")" = "true" ]
  [ "$(yq "${job}.steps[] | select(.id == \"duplicate\") | .with.lessons-dir" "${WORKFLOW}")" = "tests/fixtures/lessons/duplicate-number" ]
  yq "${job}.steps[].env.OUTCOME" "${WORKFLOW}" | grep -qx '${{ steps.duplicate.outcome }}'
  # The composite's own report, not a second dotf run that would pass even when
  # the fixture's install failed.
  local check="${job}.steps[] | select(.env.OUTCOME == \"\${{ steps.duplicate.outcome }}\") | .run"
  yq "${check}" "${WORKFLOW}" | grep -q 'RUNNER_TEMP}/hygiene-lessons.txt'
  run yq "${check}" "${WORKFLOW}"
  [[ "${output}" != *"dotf lessons"* ]]
}

@test "smoke-hygiene expects a workflow and an action pinned by tag to fail, naming each line" {
  local job=".jobs.smoke-hygiene"
  [ "$(yq "${job}.steps[] | select(.id == \"tagged\") | .continue-on-error" "${WORKFLOW}")" = "true" ]
  [ "$(yq "${job}.steps[] | select(.id == \"tagged\") | .with.lessons" "${WORKFLOW}")" = "false" ]
  yq "${job}.steps[].env.OUTCOME" "${WORKFLOW}" | grep -qx '${{ steps.tagged.outcome }}'
  run yq "${job}.steps[] | select(.env.OUTCOME == \"\${{ steps.tagged.outcome }}\") | .run" "${WORKFLOW}"
  [[ "${output}" == *'RUNNER_TEMP}/hygiene-pinned-actions.txt'* ]]
  [[ "${output}" == *"zz-hygiene-smoke.yml:"* ]]
  [[ "${output}" == *"zz-hygiene-smoke/action.yml:"* ]]
  [[ "${output}" != *"dotf lint"* ]]
}

@test "the gate needs smoke-hygiene" {
  yq '.jobs.gate.needs[]' "${WORKFLOW}" | grep -qx smoke-hygiene
}

@test "the spec's feature list parses and gives every feature a verification" {
  run jq -e 'all(.[]; (.verification | type) == "string" and (.verification | length) > 0)' \
    "${BATS_TEST_DIRNAME}/../specs/CI-005-hygiene/features.json"
  [ "$status" -eq 0 ]
}
