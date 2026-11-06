#!/usr/bin/env bats
#
# The shape of the reusable pages workflow (CI-006, #32). Each rule runs against
# the workflow and against a fixture that breaks it, so a check that stopped
# matching fails here.

ROOT="${BATS_TEST_DIRNAME}/.."
WORKFLOW="${ROOT}/.github/workflows/pages.yml"
BAD="${BATS_TEST_DIRNAME}/fixtures/pages-shape-bad.yml"

only_workflow_call() { [ "$(yq '.on | keys | join(",")' "$1")" = "workflow_call" ]; }

# A required input would break every caller pinned below it (AGENTS.md rule 5).
defaults_every_input() {
  [ "$(yq '[.on.workflow_call.inputs[] | select(.required == true or has("default") | not)] | length' "$1")" = "0" ]
}

declares_no_secret() { [ "$(yq '.on.workflow_call | has("secrets")' "$1")" = "false" ]; }

no_branch_literal() { ! yq '... comments=""' "$1" | grep -Ew 'main|master'; }

no_caller_owned_keys() { [ "$(yq 'has("permissions") or has("concurrency")' "$1")" = "false" ]; }

# The check contexts are `<caller job> / build` and `<caller job> / deploy`.
jobs_are_build_and_deploy() { [ "$(yq '.jobs | keys | join(",")' "$1")" = "build,deploy" ]; }

pins_every_action() {
  [ "$(yq '[.jobs[].steps[] | select(has("uses")) | .uses] | length' "$1")" -gt 0 ] &&
    [ -z "$(yq '.jobs[].steps[] | select(has("uses")) | .uses' "$1" | grep -Ev '^[^@]+@[0-9a-f]{40}$')" ] &&
    [ -z "$(grep -E '^\s+(- )?uses: ' "$1" | grep -Ev '@[0-9a-f]{40} # v[0-9][0-9.]*$')" ]
}

build_reads_only() { [ "$(yq -o=json -I=0 '.jobs.build.permissions' "$1")" = '{"contents":"read"}' ]; }

deploy_asks_for_pages_only() {
  [ "$(yq -o=json -I=0 '.jobs.deploy.permissions | to_entries | sort_by(.key) | from_entries' "$1")" = '{"id-token":"write","pages":"write"}' ]
}

every_job_has_a_timeout() { [ "$(yq '[.jobs[] | select(has("timeout-minutes") | not)] | length' "$1")" = "0" ]; }

checkout_drops_credentials() {
  [ "$(yq '.jobs.build.steps[] | select(.uses == "actions/checkout@*") | .with.persist-credentials' "$1")" = "false" ]
}

deploy_skips_pull_requests() {
  [ "$(yq '.jobs.deploy.if' "$1")" = "github.event_name != 'pull_request'" ] &&
    [ "$(yq '.jobs.build.steps[] | select(.uses == "actions/upload-pages-artifact@*") | .if' "$1")" = "github.event_name != 'pull_request'" ]
}

# Two hops: the deploy step's output becomes the job's, and the job's the workflow's.
publishes_page_url() {
  [ "$(yq '.on.workflow_call.outputs.page_url.value' "$1")" = '${{ jobs.deploy.outputs.page_url }}' ] &&
    [ "$(yq '.jobs.deploy.outputs.page_url' "$1")" = '${{ steps.deployment.outputs.page_url }}' ]
}

# An empty check_command is skipped, never run as an empty script.
check_is_optional() { [ "$(yq '.jobs.build.steps[] | select(.name == "Check") | .if' "$1")" = "inputs.check_command != ''" ]; }

# Inputs reach run: blocks through env, never by interpolation into the script.
no_input_interpolated_in_run() { ! yq '.jobs[].steps[] | select(has("run")) | .run' "$1" | grep -q '\${{'; }

assert_rule() {
  run "$1" "${WORKFLOW}"
  [ "${status}" -eq 0 ]
  run "$1" "${BAD}"
  [ "${status}" -ne 0 ]
}

@test "workflow_call is the only trigger" { assert_rule only_workflow_call; }
@test "every input has a default" { assert_rule defaults_every_input; }
@test "no secret is declared" { assert_rule declares_no_secret; }
@test "no branch name is hard-coded" { assert_rule no_branch_literal; }
@test "top-level permissions and concurrency stay with the caller" { assert_rule no_caller_owned_keys; }
@test "the jobs are build and deploy" { assert_rule jobs_are_build_and_deploy; }
@test "every action is pinned by full SHA with its tag as a comment" { assert_rule pins_every_action; }
@test "build asks only to read contents" { assert_rule build_reads_only; }
@test "deploy asks only for pages and id-token" { assert_rule deploy_asks_for_pages_only; }
@test "every job has a timeout" { assert_rule every_job_has_a_timeout; }
@test "checkout does not persist credentials" { assert_rule checkout_drops_credentials; }
@test "a pull request builds but neither uploads nor deploys" { assert_rule deploy_skips_pull_requests; }
@test "page_url reaches the caller" { assert_rule publishes_page_url; }
@test "an empty check command is skipped" { assert_rule check_is_optional; }
@test "inputs reach run blocks through env" { assert_rule no_input_interpolated_in_run; }
