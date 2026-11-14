#!/usr/bin/env bats
#
# The shared job's class guard (CI-007 fork 2b, #82). The triage reads a
# finding's class from a line the caller's .pr_agent.toml asks the reviewer
# for, using the prefix and classes harness/review-attestation.json names.
# These tests run the step's own script against fixtures, with `gh api`
# answering from a fixture directory, as the default branch would.

bats_require_minimum_version 1.5.0

ROOT="${BATS_TEST_DIRNAME}/.."
SHARED="${ROOT}/.github/workflows/pr-agent.yml"
FIXTURES="${BATS_TEST_DIRNAME}/fixtures/class-guard"
STEP_NAME="Check the class paragraph against the registry"

setup() {
  export RUNNER_TEMP="${BATS_TEST_TMPDIR}"
  export GITHUB_REPOSITORY=mlorentedev/example DEFAULT_BRANCH=main
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  # A stand-in for `gh api repos/<repo>/contents/<path>?ref=<branch> -H ...`:
  # prints the fixture file, a 404 when it is absent, or the error GH_FAIL names.
  cat >"${BATS_TEST_TMPDIR}/bin/gh" <<'EOF'
#!/usr/bin/env bash
path="${2#repos/*/contents/}"
path="${path%%\?*}"
if [ -n "${GH_FAIL:-}" ]; then echo "gh: ${GH_FAIL}" >&2; exit 1; fi
if [ -f "${REPO_DIR}/${path}" ]; then cat "${REPO_DIR}/${path}"; exit 0; fi
echo "gh: Not Found (HTTP 404)" >&2
exit 1
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/gh"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

step() { yq ".jobs.review.steps[] | select(.name == \"${STEP_NAME}\")" "${SHARED}"; }

# Runs the step's script the way a run: block runs, against one repository.
guard() { REPO_DIR="$1" run bash -e -c "$(step | yq '.run')"; }

@test "the step exists, before the review is routed" {
  [ "$(step | yq '.id')" = "class_guard" ]
  order=$(yq '[.jobs.review.steps[].id] | map(select(. == "credential" or . == "class_guard" or . == "route")) | join(",")' "${SHARED}")
  [ "${order}" = "credential,class_guard,route" ]
}

@test "a failed guard stops the review, and the publish guard does not blame the model" {
  yq '.jobs.review.steps[] | select(.id == "route") | .if' "${SHARED}" | grep -qF "steps.class_guard.outcome == 'success'"
  yq '.jobs.review.steps[] | select(.name == "Fail if no review was published") | .if' "${SHARED}" |
    grep -qF "steps.class_guard.outcome != 'failure'"
}

@test "a paragraph that asks for every class passes" {
  guard "${FIXTURES}/agree"
  [ "${status}" -eq 0 ]
}

@test "a repository with neither the paragraph nor the registry block passes" {
  guard "${FIXTURES}/neither"
  [ "${status}" -eq 0 ]
}

@test "a repository with no .pr_agent.toml and no registry passes" {
  guard "${BATS_TEST_TMPDIR}"
  [ "${status}" -eq 0 ]
}

@test "a registry block with no paragraph fails" {
  guard "${FIXTURES}/paragraph-missing"
  [ "${status}" -ne 0 ]
  grep -qF 'Class: REAL' <<<"${output}"
}

@test "a registry block with no .pr_agent.toml at all fails" {
  guard "${FIXTURES}/toml-missing"
  [ "${status}" -ne 0 ]
}

@test "a paragraph that drops one class fails and names it" {
  guard "${FIXTURES}/class-missing"
  [ "${status}" -ne 0 ]
  grep -qF 'Class: THEORETICAL' <<<"${output}"
  run ! grep -qF 'Class: REAL;' <<<"${output}"
}

@test "a registry whose prefix the paragraph does not use fails" {
  guard "${FIXTURES}/prefix-differs"
  [ "${status}" -ne 0 ]
  grep -qF 'Severity: REAL' <<<"${output}"
}

@test "a paragraph with no registry block fails" {
  guard "${FIXTURES}/registry-missing"
  [ "${status}" -ne 0 ]
  grep -qF 'no classification block' <<<"${output}"
}

@test "a read that fails other than with 404 fails the guard" {
  GH_FAIL="HTTP 502: Bad Gateway" guard "${FIXTURES}/agree"
  [ "${status}" -ne 0 ]
  grep -qF 'Could not read' <<<"${output}"
}

# The kit's paragraph is what every adopter copies, so it must pass against
# this repository's own registry.
@test "the kit's paragraph agrees with this repository's registry" {
  repo="${BATS_TEST_TMPDIR}/kit"
  mkdir -p "${repo}/harness"
  cp "${ROOT}/harness/review-attestation.json" "${repo}/harness/"
  printf '[pr_reviewer]\nextra_instructions = """\n%s\n"""\n' \
    "$(cat "${ROOT}/specs/CI-007-fleet-pr-agent/kit/class-paragraph.txt")" >"${repo}/.pr_agent.toml"
  guard "${repo}"
  [ "${status}" -eq 0 ]
}

@test "this repository's own toml and registry agree" {
  repo="${BATS_TEST_TMPDIR}/self"
  mkdir -p "${repo}/harness"
  cp "${ROOT}/.pr_agent.toml" "${repo}/"
  cp "${ROOT}/harness/review-attestation.json" "${repo}/harness/"
  guard "${repo}"
  [ "${status}" -eq 0 ]
}
