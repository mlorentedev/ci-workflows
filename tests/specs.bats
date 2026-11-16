#!/usr/bin/env bats
#
# Every spec's feature list, active or archived (#46). Nothing else in CI reads
# them, and `dotf spec archive` reads one only at the end of a spec's life, so a
# list that stops parsing would otherwise surface months late. Each rule also
# runs against a list that breaks it.

bats_require_minimum_version 1.5.0

ROOT="${BATS_TEST_DIRNAME}/.."

feature_lists() { compgen -G "${ROOT}/specs/*/features.json"; compgen -G "${ROOT}/specs/archive/*/features.json"; }

# Exactly one JSON document: a non-empty array whose every entry names a
# non-empty verification command. --slurp, because `jq -e` alone judges each
# document in a stream and answers for the last one.
valid_feature_list() {
  jq -se 'length == 1 and (.[0] | type == "array" and length > 0
    and all(.[]; type == "object" and (.verification | type) == "string" and (.verification | length) > 0))' \
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

@test "the rule rejects invalid JSON, an empty file, two documents, an empty list and a missing or empty verification" {
  run ! valid_feature_list "$(broken '[{"id": "x", "verification": "bats tests/x.bats"')"
  run ! valid_feature_list "$(broken '')"
  run ! valid_feature_list "$(broken '[] [{"id": "x", "verification": "bats tests/x.bats"}]')"
  run ! valid_feature_list "$(broken '[]')"
  run ! valid_feature_list "$(broken '[{"id": "x"}]')"
  run ! valid_feature_list "$(broken '[{"id": "x", "verification": ""}]')"
  valid_feature_list "$(broken '[{"id": "x", "verification": "bats tests/x.bats"}]')"
}

# A spec folder moves to specs/archive/ when the spec closes, so a workflow or a
# test that reads a file inside an active one breaks on the day it archives
# (CI-007's kit, lesson 020). Durable files live outside specs/. Any folder
# name counts except archive/, whatever the id's shape (CI-007-x, ADR028-004,
# 2026-05-13-cleanup). docs/ is not scanned: lessons and ADRs cite spec paths
# as history, and a dead link there breaks nothing.
active_spec_paths() {
  grep -rnoE 'specs/[A-Za-z0-9][A-Za-z0-9._-]*/' "$@" 2>/dev/null | grep -v ':specs/archive/$'
}

@test "no workflow or test reads a file inside an active spec folder" {
  run active_spec_paths "${ROOT}/.github" "${ROOT}/tests" "${ROOT}/harness" \
    "${ROOT}/renovate" "${ROOT}/pr-agent" "${ROOT}/README.md"
  [ "$status" -eq 1 ] || { printf '%s\n' "${output}"; false; }
}

@test "the active-spec check finds such a path" {
  mkdir -p "${BATS_TEST_TMPDIR}/wf"
  local id
  for id in CI-099-x ADR028-004 2026-05-13-cleanup; do
    printf 'cat specs/%s/kit/a.txt\n' "${id}" >"${BATS_TEST_TMPDIR}/wf/${id}.yml"
  done
  printf 'cat specs/archive/CI-004-x/features.json\n' >"${BATS_TEST_TMPDIR}/wf/archived.yml"
  run active_spec_paths "${BATS_TEST_TMPDIR}/wf"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [[ "${output}" != *archived.yml* ]]
}
