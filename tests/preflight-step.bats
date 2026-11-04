#!/usr/bin/env bats
#
# The preflight step of pr-agent.yml (TOOL-031, dotfiles#2893). Its run block
# executes here against a stub dotf, so the chain it passes is read, not inferred.

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/pr-agent.yml"

setup() {
  export STUBS="${BATS_TEST_TMPDIR}/bin"
  export GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/output"
  export DOTF_ARGS="${BATS_TEST_TMPDIR}/dotf-args"
  export POOL=embedded DECLARED_MODEL="" DECLARED_FALLBACK_MODELS=""
  mkdir -p "${STUBS}"
  : >"${GITHUB_OUTPUT}"
  cat >"${STUBS}/dotf" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${DOTF_ARGS}"
exit "${DOTF_EXIT:-0}"
STUB
  chmod +x "${STUBS}/dotf"
  yq '.jobs.review.steps[] | select(.id == "models") | .run' "${WORKFLOW}" >"${BATS_TEST_TMPDIR}/step.sh"
}

run_step() { PATH="${STUBS}:${PATH}" run bash -eo pipefail "${BATS_TEST_TMPDIR}/step.sh"; }

@test "with nothing declared the chain is the pool's" {
  POOL=harness/reviewer-pool.json run_step
  [ "${status}" -eq 0 ]
  [ "$(head -3 "${DOTF_ARGS}" | paste -sd' ' -)" = "pr preflight --pool" ]
  sed -n 4p "${DOTF_ARGS}" | grep -qx 'harness/reviewer-pool.json'
  ! grep -q -- '--model' "${DOTF_ARGS}"
}

@test "a declared chain replaces the pool's" {
  DECLARED_MODEL=openai/a DECLARED_FALLBACK_MODELS='["openai/b"]' run_step
  [ "${status}" -eq 0 ]
  [ "$(paste -sd' ' "${DOTF_ARGS}")" = "pr preflight --model openai/a --fallbacks [\"openai/b\"] --output ${GITHUB_OUTPUT}" ]
}

@test "the preflight's exit status is published and kept" {
  DOTF_EXIT=1 run_step
  [ "${status}" -eq 1 ]
  grep -qx 'exit=1' "${GITHUB_OUTPUT}"
}
