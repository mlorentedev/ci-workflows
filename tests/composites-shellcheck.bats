#!/usr/bin/env bats
#
# actionlint reads .github/workflows/ only, so the shell in a composite action is
# never shellchecked by lint.yml. This runs shellcheck over every `run:` step of
# every composite in .github/actions/.

ACTIONS="${BATS_TEST_DIRNAME}/../.github/actions"

@test "every composite's run steps pass shellcheck" {
  command -v shellcheck >/dev/null || skip "shellcheck is not installed"
  local checked=0 action i n
  for action in "${ACTIONS}"/*/action.yml; do
    n=$(yq '.runs.steps | length' "${action}")
    for ((i = 0; i < n; i++)); do
      [ "$(yq ".runs.steps[${i}].run // \"\"" "${action}")" ] || continue
      yq ".runs.steps[${i}].run" "${action}" >"${BATS_TEST_TMPDIR}/step.sh"
      run shellcheck -s bash "${BATS_TEST_TMPDIR}/step.sh"
      [ "$status" -eq 0 ] || { echo "${action} step ${i}: ${output}"; return 1; }
      checked=$((checked + 1))
    done
  done
  [ "${checked}" -ge 4 ]
}
