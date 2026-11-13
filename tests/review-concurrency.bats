#!/usr/bin/env bats
#
# The concurrency key of this repository's own review caller (#75). The key is
# workflow, PR number and event name; on top of that, a comment the shared job
# would not run, and a bot's push, each get a group of their own. Without the
# first, any comment cancels an in-flight /review and the replacement run skips
# itself; without the second, a bot push cancels a human review and the shared
# job then ignores the bot commit, so the PR is never reviewed (dotfiles #2855).
# The CI-007 kit hands adopters the same key, so the two must not drift.

bats_require_minimum_version 1.5.0

ROOT="${BATS_TEST_DIRNAME}/.."
CALLER="${ROOT}/.github/workflows/review.yml"
KIT="${ROOT}/specs/CI-007-fleet-pr-agent/kit/pr-agent.yml"
SHARED="${ROOT}/.github/workflows/pr-agent.yml"

group_of() { yq '.concurrency.group' "$1"; }

# The trusted-association list, as written in the file's first fromJSON array.
associations_in() { grep -o "fromJSON('\[[^]]*\]')" | head -n 1; }

@test "the caller and the kit share one concurrency key" {
  [ -n "$(group_of "${CALLER}")" ]
  [ "$(group_of "${CALLER}")" = "$(group_of "${KIT}")" ]
}

@test "the key trusts the same associations as the shared job's if" {
  shared="$(yq '.jobs.review.if' "${SHARED}" | associations_in)"
  [ -n "${shared}" ]
  [ "$(group_of "${CALLER}" | associations_in)" = "${shared}" ]
}

@test "a comment the shared job skips gets a group of its own" {
  group_of "${CALLER}" | grep -Fq "format('-{0}', github.event.comment.id)"
}

# The commands PR-Agent runs as a review: command2class at the audited ref maps
# these four to its reviewer (#113). Only they share the review group (#91); any
# other trusted comment, /improve or a path, would cancel an in-flight review.
REVIEW_COMMANDS="/answer /auto_review /review /review_pr"

# Each command the key names, as the sorted set of its "'/cmd '" literals.
key_commands() {
  group_of "$1" | grep -oE "'/[a-z_]+ '" | tr -d "' " | sort -u | tr '\n' ' ' | sed 's/ $//'
}

# The classification step of the shared job, and the commands its case names.
classify_step() { yq '.jobs.review.steps[] | select(.id == "command")' "${SHARED}"; }
step_commands() {
  classify_step | yq '.run' | grep -E '^\s*/' | head -n 1 | sed 's/).*//' |
    tr '|' '\n' | tr -d ' ' | sort -u | tr '\n' ' ' | sed 's/ $//'
}

# Runs the step's own script on a comment body and prints its decision.
classify() {
  local out
  out="$(mktemp)"
  BODY="$1" GITHUB_OUTPUT="${out}" bash -c "$(classify_step | yq '.run')"
  sed -n 's/^review=//p' "${out}"
}

@test "the key shares the group for exactly PR-Agent's review commands" {
  [ "$(key_commands "${CALLER}")" = "${REVIEW_COMMANDS}" ]
}

@test "the shared job classifies the same commands as the key" {
  [ "$(step_commands)" = "${REVIEW_COMMANDS}" ]
}

@test "every review command is ended by a tab, a newline or a carriage return too" {
  for cmd in ${REVIEW_COMMANDS}; do
    for sep in 't' 'n' 'r'; do
      group_of "${CALLER}" | grep -Fq "format('${cmd}{0}', fromJSON('\"\\${sep}\"'))"
    done
  done
}

@test "a word that only begins with /review, such as /reviewed, gets its own group" {
  [ -z "$(group_of "${CALLER}" | grep -F "startsWith(github.event.comment.body, '/review')")" ]
  [ -z "$(group_of "${CALLER}" | grep -F "github.event.comment.body == ")" ]
}

@test "every publish gate reads the step, not the comment body" {
  [ "$(yq '[.jobs.review.steps[] | select((.if // "") | test("steps.command.outputs.review == .true."))] | length' "${SHARED}")" = "4" ]
  [ "$(yq '[.jobs.review.steps[] | select((.if // "") | test("comment.body"))] | length' "${SHARED}")" = "0" ]
}

@test "the step runs a review for every spelling PR-Agent accepts" {
  [ "$(classify '/review')" = "true" ]
  [ "$(classify '/review --pr_reviewer.extra_instructions=x')" = "true" ]
  [ "$(classify $'/review\nplease look again')" = "true" ]
  [ "$(classify $'/review\r\nsecond line')" = "true" ]
  [ "$(classify $'/review\tx')" = "true" ]
  [ "$(classify '/Review')" = "true" ]
  [ "$(classify '/review_pr')" = "true" ]
  [ "$(classify '/auto_review')" = "true" ]
  [ "$(classify '/answer')" = "true" ]
}

@test "the step runs no review for anything else" {
  [ "$(classify '/reviewed')" = "false" ]
  [ "$(classify '/improve')" = "false" ]
  [ "$(classify '/describe')" = "false" ]
  [ "$(classify '/ask what is this')" = "false" ]
  [ "$(classify '/src/review.go looks off')" = "false" ]
  # shlex splits on space, tab, CR and LF only, so PR-Agent reads these as one
  # unknown command.
  [ "$(classify $'/review\fx')" = "false" ]
  [ "$(classify $'/review\vx')" = "false" ]
}

@test "a bot's push gets a group of its own" {
  group_of "${CALLER}" | grep -Fq "endsWith(github.actor, '[bot]')"
  group_of "${CALLER}" | grep -Fq "format('-{0}', github.run_id)"
}

@test "a newer run of the same key still cancels the older one" {
  [ "$(yq '.concurrency.cancel-in-progress' "${CALLER}")" = "true" ]
}
