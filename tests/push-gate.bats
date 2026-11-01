#!/usr/bin/env bats
#
# The push-gate action (TOOL-031, dotfiles#2893). The step's script runs here
# the way a composite runs it, against stubs of gh and dotf, so a gate that errors
# has to fail the step rather than be read as a decision.

ACTION="${BATS_TEST_DIRNAME}/../.github/actions/push-gate/action.yml"

setup() {
  export STUBS="${BATS_TEST_TMPDIR}/bin"
  export GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/output"
  export DOTF_CALLS="${BATS_TEST_TMPDIR}/dotf-calls"
  export GITHUB_REPOSITORY=owner/repo PR_NUMBER=7 SENDER_TYPE=User
  mkdir -p "${STUBS}"
  : >"${GITHUB_OUTPUT}"
  cat >"${STUBS}/gh" <<'STUB'
#!/usr/bin/env bash
[ -z "${GH_FAILS:-}" ] || exit 1
echo '[]'
STUB
  cat >"${STUBS}/dotf" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"${DOTF_CALLS}"
for f in comments commits; do
  [ -f "$(dirname "$4")/${f}.json" ] && echo "read ${f}" >>"${DOTF_CALLS}"
done
echo run=true
echo mode=full
exit "${DOTF_EXIT:-0}"
STUB
  chmod +x "${STUBS}/gh" "${STUBS}/dotf"
  PATH="${STUBS}:${PATH}"
  yq '.runs.steps[0].run' "${ACTION}" >"${BATS_TEST_TMPDIR}/step.sh"
}

run_step() { run bash --noprofile --norc -eo pipefail "${BATS_TEST_TMPDIR}/step.sh"; }

@test "the step runs under bash, whose pipefail keeps the gate's status" {
  [ "$(yq '.runs.steps[0].shell' "${ACTION}")" = "bash" ]
}

@test "the gate's decision reaches the action's outputs" {
  run_step
  [ "${status}" -eq 0 ]
  grep -qx 'run=true' "${GITHUB_OUTPUT}"
  grep -qx 'mode=full' "${GITHUB_OUTPUT}"
  for output in run mode reason; do
    [ "$(yq ".outputs.${output}.value" "${ACTION}")" = "\${{ steps.gate.outputs.${output} }}" ]
  done
}

@test "the gate reads both files and the sender" {
  run_step
  grep -qx 'read comments' "${DOTF_CALLS}"
  grep -qx 'read commits' "${DOTF_CALLS}"
  grep -q -- '--sender-type User' "${DOTF_CALLS}"
}

@test "a gate that errors fails the step" {
  DOTF_EXIT=2 run_step
  [ "${status}" -eq 2 ]
}

@test "a failed read reaches the gate as a missing file" {
  GH_FAILS=1 run_step
  [ "${status}" -eq 0 ]
  [ -s "${DOTF_CALLS}" ]
  ! grep -q '^read ' "${DOTF_CALLS}"
}
