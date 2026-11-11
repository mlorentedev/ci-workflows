#!/usr/bin/env bats
#
# A reusable workflow's `on.workflow_call.secrets` is the list of secrets a
# caller must hold (dotfiles#3290 reads it at the caller's pinned ref to tell
# each repository which CI secrets it needs, and which it holds for nothing).
# So the declaration must be complete and exact: every secret the workflow reads
# is declared, and every declared secret is read. Composite actions cannot read
# secrets at all, so they take credentials as inputs and need no entry.

bats_require_minimum_version 1.5.0

WORKFLOWS="${BATS_TEST_DIRNAME}/../.github/workflows"
ACTIONS="${BATS_TEST_DIRNAME}/../.github/actions"

declared() { yq '.on.workflow_call.secrets // {} | keys | .[]' "$1" | sort -u; }

# Both property forms count: secrets.NAME and secrets['NAME'] (or "NAME").
# GITHUB_TOKEN is the runner's own, never a caller's secret.
read_secrets() {
  grep -oE "secrets(\.[A-Za-z0-9_]+|\[['\"][A-Za-z0-9_]+['\"]\])" "$1" |
    sed -E "s/^secrets[.[]['\"]?//; s/['\"]?\]?$//" | grep -vx GITHUB_TOKEN | sort -u || true
}

# An expression that takes the whole context (toJSON(secrets), secrets[matrix.x])
# reads names no declaration can list, so it is refused outright.
whole_context() { grep -oE '\$\{\{[^}]*\}\}' "$1" | grep -E "secrets([^.[A-Za-z0-9_]|\[[^'\"]|$)" || true; }

# GitHub accepts both extensions for workflows and for action manifests.
shopt -s nullglob

@test "every reusable workflow declares exactly the secrets it reads" {
  local f n=0 bad=0
  for f in "${WORKFLOWS}"/*.yml "${WORKFLOWS}"/*.yaml; do
    [ "$(yq '.on | has("workflow_call")' "${f}")" = "true" ] || continue
    n=$((n + 1))
    if [ -n "$(whole_context "${f}")" ]; then
      echo "${f##*/}: reads the whole secrets context: $(whole_context "${f}")"
      bad=1
    fi
    if [ "$(declared "${f}")" != "$(read_secrets "${f}")" ]; then
      echo "${f##*/}: declares [$(declared "${f}" | xargs)] but reads [$(read_secrets "${f}" | xargs)]"
      bad=1
    fi
  done
  # A broken selector would check nothing and pass.
  [ "${n}" -ge 3 ]
  [ "${bad}" -eq 0 ]
}

@test "the check catches a secret read but not declared" {
  cat >"${BATS_TEST_TMPDIR}/wf.yml" <<'YAML'
on:
  workflow_call:
    secrets:
      A_TOKEN: { required: true }
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ secrets.A_TOKEN }} ${{ secrets['B_TOKEN'] }} ${{ secrets["C_TOKEN"] }} ${{ secrets.GITHUB_TOKEN }}"
YAML
  [ "$(declared "${BATS_TEST_TMPDIR}/wf.yml")" = "A_TOKEN" ]
  [ "$(read_secrets "${BATS_TEST_TMPDIR}/wf.yml" | xargs)" = "A_TOKEN B_TOKEN C_TOKEN" ]
  [ -z "$(whole_context "${BATS_TEST_TMPDIR}/wf.yml")" ]
}

@test "the check refuses an expression that reads the whole secrets context" {
  printf '%s\n' 'x: ${{ toJSON(secrets) }}' >"${BATS_TEST_TMPDIR}/a.yml"
  printf '%s\n' 'x: ${{ secrets[matrix.name] }}' >"${BATS_TEST_TMPDIR}/b.yml"
  [ -n "$(whole_context "${BATS_TEST_TMPDIR}/a.yml")" ]
  [ -n "$(whole_context "${BATS_TEST_TMPDIR}/b.yml")" ]
}

@test "no composite action reads a secret" {
  local manifests=("${ACTIONS}"/*/action.yml "${ACTIONS}"/*/action.yaml)
  # An empty glob would grep nothing, fail, and pass under run !.
  [ "${#manifests[@]}" -ge 3 ]
  run ! grep -lE 'secrets(\.|\[)|toJSON\(secrets\)' "${manifests[@]}"
}
