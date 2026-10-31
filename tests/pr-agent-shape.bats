#!/usr/bin/env bats
#
# The shape of the reusable pr-agent workflow (TOOL-031, dotfiles#2893). Each
# rule runs against the workflow and against a fixture that breaks it, so a
# check that stopped matching fails here instead of passing everything.

# The workflow is not written yet. When it lands, point this at
# .github/workflows/pr-agent.yml and delete pr-agent-shape-good.yml.
WORKFLOW="${WORKFLOW:-${BATS_TEST_DIRNAME}/fixtures/pr-agent-shape-good.yml}"
BAD="${BATS_TEST_DIRNAME}/fixtures/pr-agent-shape-bad.yml"

only_workflow_call() { [ "$(yq '.on | keys | join(",")' "$1")" = "workflow_call" ]; }

declares_secrets() {
  [ "$(yq '.on.workflow_call.secrets.NAN_API_KEY.required' "$1")" = "true" ] &&
    [ "$(yq '.on.workflow_call.secrets.PR_AGENT_ANTHROPIC_API_KEY.required' "$1")" = "false" ]
}

no_secrets_inherit() { [ "$(yq '[.jobs[].secrets | select(. == "inherit")] | length' "$1")" = "0" ]; }

no_branch_literal() { ! yq '... comments=""' "$1" | grep -Ew 'main|master'; }

no_caller_owned_keys() {
  [ "$(yq 'has("permissions") or has("concurrency")' "$1")" = "false" ]
}

no_github_workflow_sha() { ! grep -q 'github\.workflow_sha' "$1"; }

requires_dotf_version() {
  [ "$(yq '.on.workflow_call.inputs.dotf_version.required' "$1")" = "true" ]
}

# Reads the commands the steps run, so a comment naming them does not count.
verifies_checksum() {
  yq '.jobs[].steps[]?.run // ""' "$1" | grep -Ev '^[[:space:]]*#' |
    grep -E 'checksums\.txt.*sha256sum -c|sha256sum -c.*checksums\.txt'
}

assert_rule() {
  run "$1" "${WORKFLOW}"
  [ "${status}" -eq 0 ]
  run "$1" "${BAD}"
  [ "${status}" -ne 0 ]
}

@test "workflow_call is the only trigger" { assert_rule only_workflow_call; }
@test "NAN_API_KEY is required and the Anthropic key optional" { assert_rule declares_secrets; }
@test "secrets are not inherited" { assert_rule no_secrets_inherit; }
@test "no branch name is hard-coded" { assert_rule no_branch_literal; }
@test "top-level permissions and concurrency stay with the caller" { assert_rule no_caller_owned_keys; }
@test "github.workflow_sha is not read" { assert_rule no_github_workflow_sha; }
@test "dotf_version is a required input" { assert_rule requires_dotf_version; }
@test "the dotf install verifies a checksum" { assert_rule verifies_checksum; }
