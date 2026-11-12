#!/usr/bin/env bats
#
# The NaN review step's budget (#88, #87). The shared step owns the prompt
# budget, the per-call timeout and the step bound, and the three must agree:
# the budget sits below the model capacity, or the guardrail never fires and a
# whole diff goes out (svqtriana.github.io run 42562380120); and the bound
# covers the longest chain at that timeout, or the step is killed before its
# last fallback answers (kubelab, #87). Each rule also runs on a copy that
# breaks it, so a check that stopped matching fails here.

WORKFLOW="${BATS_TEST_DIRNAME}/../.github/workflows/pr-agent.yml"

# The longest NaN chain a caller may run: the model and two fallbacks, as
# kubelab declares. SETUP covers pulling and starting the PR-Agent image.
MAX_CHAIN=3
SETUP_SECONDS=120
# Steps outside the PR-Agent ones: checkout, dotf install, preflight, route, guards.
OVERHEAD_MINUTES=6

nan_env() { yq ".jobs.review.steps[] | select(.id == \"pr_agent\") | .env.$2" "$1"; }
step_minutes() { yq ".jobs.review.steps[] | select(.id == \"$2\") | .\"timeout-minutes\"" "$1"; }

budget_below_capacity() {
  local budget capacity
  budget=$(nan_env "$1" CONFIG__MAX_MODEL_TOKENS)
  capacity=$(nan_env "$1" CONFIG__CUSTOM_MODEL_MAX_TOKENS)
  [[ "${budget}" =~ ^[0-9]+$ && "${capacity}" =~ ^[0-9]+$ ]] && [ "${budget}" -lt "${capacity}" ]
}

# Each model in the chain makes one call plus its client retries; a timed-out
# call is retried on the same model only when retry_same_model_on_timeout is on,
# which the arithmetic does not allow for, so it must be off.
chain_fits_the_step() {
  local timeout minutes retries same
  timeout=$(nan_env "$1" CONFIG__AI_TIMEOUT)
  minutes=$(step_minutes "$1" pr_agent)
  retries=$(nan_env "$1" CONFIG__NUM_RETRIES)
  same=$(nan_env "$1" CONFIG__RETRY_SAME_MODEL_ON_TIMEOUT)
  [[ "${timeout}" =~ ^[0-9]+$ && "${minutes}" =~ ^[0-9]+$ && "${retries}" =~ ^[0-9]+$ ]] &&
    [ "${same}" = "false" ] &&
    [ $((MAX_CHAIN * (1 + retries) * timeout + SETUP_SECONDS)) -le $((minutes * 60)) ]
}

# At most two PR-Agent steps run: the drawn one and the other provider after it.
steps_fit_the_job() {
  local job nan first second longest
  job=$(yq '.jobs.review."timeout-minutes"' "$1")
  nan=$(step_minutes "$1" pr_agent)
  first=$(step_minutes "$1" pr_agent_anthropic_first)
  second=$(step_minutes "$1" pr_agent_anthropic_second)
  longest=$((first > second ? first : second))
  [ $((nan + longest + OVERHEAD_MINUTES)) -le "${job}" ]
}

broken() { # $1 = a yq edit; prints a copy of the workflow with it applied
  local copy="${BATS_TEST_TMPDIR}/pr-agent.yml"
  yq "$1" "${WORKFLOW}" >"${copy}"
  printf '%s' "${copy}"
}

assert_rule() { # $1 = rule, $2 = a yq edit that must break it
  run "$1" "${WORKFLOW}"
  [ "${status}" -eq 0 ]
  run "$1" "$(broken "$2")"
  [ "${status}" -ne 0 ]
}

NAN='.jobs.review.steps[] | select(.id == "pr_agent")'

@test "the NaN prompt budget sits below the model capacity" {
  assert_rule budget_below_capacity "(${NAN}).env.CONFIG__MAX_MODEL_TOKENS = \"200000\""
}

@test "the NaN prompt budget is set, not left to the caller" {
  assert_rule budget_below_capacity "del((${NAN}).env.CONFIG__MAX_MODEL_TOKENS)"
}

@test "the longest NaN chain fits inside the step bound" {
  assert_rule chain_fits_the_step "(${NAN}).\"timeout-minutes\" = 12"
}

@test "the NaN call timeout is set, not left to the caller" {
  assert_rule chain_fits_the_step "del((${NAN}).env.CONFIG__AI_TIMEOUT)"
}

@test "the NaN client retries are set, not left to the caller" {
  assert_rule chain_fits_the_step "del((${NAN}).env.CONFIG__NUM_RETRIES)"
}

@test "a client retry counts against the step bound" {
  assert_rule chain_fits_the_step "(${NAN}).env.CONFIG__NUM_RETRIES = \"1\""
}

@test "a timed-out call is not retried on the same model" {
  assert_rule chain_fits_the_step "(${NAN}).env.CONFIG__RETRY_SAME_MODEL_ON_TIMEOUT = \"true\""
}

@test "the review job outlasts its two longest PR-Agent steps" {
  assert_rule steps_fit_the_job '.jobs.review."timeout-minutes" = 25'
}
