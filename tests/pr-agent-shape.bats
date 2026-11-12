#!/usr/bin/env bats
#
# The shape of the reusable pr-agent workflow (TOOL-031, dotfiles#2893). Each
# rule runs against the workflow and against a fixture that breaks it, so a
# check that stopped matching fails here instead of passing everything.

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/pr-agent.yml"
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

# A default pins dotf to the workflow's own tag, so a caller bumps one pin.
dotf_version_defaults_to_a_release() {
  [ "$(yq '.on.workflow_call.inputs.dotf_version.required' "$1")" != "true" ] &&
    yq '.on.workflow_call.inputs.dotf_version.default' "$1" | grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+'
}

# Branch prefixes are the caller's, passed as skip_branch_prefixes (rule 4).
job_if_names_no_branch() { ! yq '.jobs[].if // ""' "$1" | grep -Eq 'head\.ref|head_ref'; }

# Decisions are dotf's (rule 1), so no step carries an interpreter of its own.
no_inline_interpreter() {
  ! yq '.jobs[].steps[]?.run // ""' "$1" | grep -Ev '^[[:space:]]*#' | grep -Eqw 'python3?|node|ruby|perl'
}

steps_running() { # $1 = workflow, $2 = the command the step runs
  yq ".jobs[].steps[]? | select((.run // \"\") | test(\"$2\"))" "$1"
}

# A caller opts in, a comment must ask for a review (never /improve), and a
# failed declaration does not stop the review after it.
declare_is_opt_in() {
  local step
  step=$(steps_running "$1" 'dotf pr declare-unreviewed')
  [ -n "${step}" ] &&
    yq '.if' <<<"${step}" | grep -q 'inputs.declare_unreviewed' &&
    yq '.if' <<<"${step}" | grep -q "steps.reviewable.outcome == 'success'" &&
    yq '.if' <<<"${step}" | grep -qF "contains(github.event.comment.body, '/review')" &&
    [ "$(yq '.["continue-on-error"]' <<<"${step}")" = "true" ]
}

# A PR nothing would review is skipped before a missing key can fail it.
skips_before_the_credential_check() {
  local order
  order=$(yq '[.jobs.review.steps[].id] | (to_entries | map(select(.value == "reviewable" or .value == "credential")) | map(.value) | join(","))' "$1")
  [ "${order}" = "reviewable,credential" ] &&
    [ "$(yq '.jobs.review.steps[] | select(.id == "credential") | .if' "$1")" = "steps.reviewable.outputs.reviewable != 'false'" ]
}

# With no declared chain, the preflight reads it from the pool the draw reads.
preflight_reads_the_pool() {
  [ "$(yq '.on.workflow_call.inputs.declared_model.required' "$1")" != "true" ] &&
    [ "$(yq '.on.workflow_call.inputs.declared_fallback_models.required' "$1")" != "true" ] &&
    steps_running "$1" 'dotf pr preflight' | yq '.run' | grep -q -- '--pool'
}

# Reads the commands the steps run, so a comment naming them does not count.
verifies_checksum() {
  yq '.jobs[].steps[]?.run // ""' "$1" | grep -Ev '^[[:space:]]*#' |
    grep -E 'checksums\.txt.*sha256sum -c|sha256sum -c.*checksums\.txt'
}

# ./ would resolve in the caller, so the workflow reaches its action by a pin.
uses_pinned_push_gate() {
  yq '.jobs[].steps[]?.uses // ""' "$1" |
    grep -Eq '^mlorentedev/ci-workflows/\.github/actions/push-gate@[0-9a-f]{40}$'
}

# A run a newer push superseded is cancelled, not failed. On always() the guard
# still ran there and turned the stale SHA red, indistinguishable from a NaN or
# credential failure (#85, hive#503). !cancelled() still runs it after a failed step.
guard_skips_a_cancelled_run() {
  local cond
  cond=$(steps_running "$1" 'dotf pr guard' | yq '.if')
  [ -n "${cond}" ] && [ "${cond}" != "null" ] &&
    grep -qF '!cancelled()' <<<"${cond}" && ! grep -qF 'always()' <<<"${cond}"
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
@test "dotf_version defaults to a release" { assert_rule dotf_version_defaults_to_a_release; }
@test "the job if names no branch" { assert_rule job_if_names_no_branch; }
@test "no step runs an interpreter of its own" { assert_rule no_inline_interpreter; }
@test "declare_unreviewed is opt-in and cannot stop the review" { assert_rule declare_is_opt_in; }
@test "with no declared chain the preflight reads the pool" { assert_rule preflight_reads_the_pool; }
@test "the skip runs before the credential check" { assert_rule skips_before_the_credential_check; }
@test "the dotf install verifies a checksum" { assert_rule verifies_checksum; }
@test "the push gate is the action, pinned by full SHA" { assert_rule uses_pinned_push_gate; }
@test "the publish guard does not run in a cancelled run" { assert_rule guard_skips_a_cancelled_run; }
