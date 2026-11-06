#!/usr/bin/env bats
#
# Dependabot bumps the actions this repository pins (issue #18). With `directory: /`
# it reads only .github/workflows and a root action.yml, so a composite whose
# directory no entry matches would keep its pins forever, silently.

ROOT="${BATS_TEST_DIRNAME}/.."
CONFIG="${ROOT}/.github/dependabot.yml"

# The directories of the github-actions entries, one per line.
action_dirs() {
  yq '.updates[] | select(.package-ecosystem == "github-actions") | (.directories // [.directory])[]' "${CONFIG}"
}

@test "the github-actions ecosystem covers the workflows" {
  run action_dirs
  [ "$status" -eq 0 ]
  grep -qx '/' <<<"$output"
}

@test "every composite under .github/actions is covered by a directories entry" {
  local dirs uncovered="" dir rel pattern hit checked=0
  dirs=$(action_dirs)
  for dir in "${ROOT}"/.github/actions/*/; do
    [ -f "${dir}action.yml" ] || continue
    checked=$((checked + 1))
    rel="/${dir#"${ROOT}/"}"
    rel="${rel%/}"
    hit=""
    while IFS= read -r pattern; do
      # shellcheck disable=SC2053 # the entry is a glob on purpose
      [[ "${rel}" == ${pattern} ]] && hit=1
    done <<<"${dirs}"
    [ -n "${hit}" ] || uncovered+=" ${rel}"
  done
  # A glob that matches no composite must fail, not pass with nothing checked.
  [ "${checked}" -ge 3 ] || { echo "only ${checked} composites found"; return 1; }
  [ -z "${uncovered}" ] || { echo "not covered:${uncovered}"; return 1; }
}
