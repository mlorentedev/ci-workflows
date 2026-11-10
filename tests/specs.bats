#!/usr/bin/env bats
#
# Every spec's feature list, active or archived (#46). Nothing else in CI reads
# them, and `dotf spec archive` reads one only at the end of a spec's life, so a
# list that stops parsing would otherwise surface months late. Each rule also
# runs against a list that breaks it.

ROOT="${BATS_TEST_DIRNAME}/.."

feature_lists() { compgen -G "${ROOT}/specs/*/features.json"; compgen -G "${ROOT}/specs/archive/*/features.json"; }

# A non-empty array whose every entry names a non-empty verification command.
valid_feature_list() {
  jq -e 'type == "array" and length > 0
    and all(.[]; type == "object" and (.verification | type) == "string" and (.verification | length) > 0)' \
    "$1" >/dev/null 2>&1
}

broken() { printf '%s' "$1" >"${BATS_TEST_TMPDIR}/features.json" && echo "${BATS_TEST_TMPDIR}/features.json"; }

@test "the glob finds the feature lists of active and archived specs" {
  run feature_lists
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -ge 2 ]
  printf '%s\n' "${lines[@]}" | grep -q '/specs/archive/'
  printf '%s\n' "${lines[@]}" | grep -qv '/specs/archive/'
}

@test "every feature list parses and gives each feature a verification" {
  local failed=()
  while IFS= read -r f; do
    valid_feature_list "$f" || failed+=("${f#"${ROOT}"/}")
  done < <(feature_lists)
  [ "${#failed[@]}" -eq 0 ] || { printf 'invalid feature list: %s\n' "${failed[@]}"; false; }
}

@test "the rule rejects invalid JSON, an empty list and a missing or empty verification" {
  ! valid_feature_list "$(broken '[{"id": "x", "verification": "bats tests/x.bats"')"
  ! valid_feature_list "$(broken '[]')"
  ! valid_feature_list "$(broken '[{"id": "x"}]')"
  ! valid_feature_list "$(broken '[{"id": "x", "verification": ""}]')"
  valid_feature_list "$(broken '[{"id": "x", "verification": "bats tests/x.bats"}]')"
}
