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

# GITHUB_TOKEN is the runner's own, never a caller's secret.
read_secrets() { grep -oE 'secrets\.[A-Za-z0-9_]+' "$1" | cut -d. -f2 | grep -vx GITHUB_TOKEN | sort -u || true; }

@test "every reusable workflow declares exactly the secrets it reads" {
  local f n=0 bad=0
  for f in "${WORKFLOWS}"/*.yml; do
    [ "$(yq '.on | has("workflow_call")' "${f}")" = "true" ] || continue
    n=$((n + 1))
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
      - run: echo "${{ secrets.A_TOKEN }} ${{ secrets.B_TOKEN }} ${{ secrets.GITHUB_TOKEN }}"
YAML
  [ "$(declared "${BATS_TEST_TMPDIR}/wf.yml")" = "A_TOKEN" ]
  [ "$(read_secrets "${BATS_TEST_TMPDIR}/wf.yml" | xargs)" = "A_TOKEN B_TOKEN" ]
}

@test "no composite action reads a secret" {
  run ! grep -lE 'secrets\.' "${ACTIONS}"/*/action.yml
}
