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

# Only /review shares the review group (#91). A trusted comment that merely
# starts with a slash (a path, or /improve) would otherwise cancel an in-flight
# /review, and the run replacing it publishes no Guide.
@test "only a /review command shares the comment group" {
  group_of "${CALLER}" | grep -Fq "github.event.comment.body == '/review'"
  group_of "${CALLER}" | grep -Fq "startsWith(github.event.comment.body, '/review ')"
  [ -z "$(group_of "${CALLER}" | grep -F "startsWith(github.event.comment.body, '/')")" ]
}

@test "a word that only begins with /review, such as /reviewed, gets its own group" {
  [ -z "$(group_of "${CALLER}" | grep -F "startsWith(github.event.comment.body, '/review')")" ]
}

@test "a bot's push gets a group of its own" {
  group_of "${CALLER}" | grep -Fq "endsWith(github.actor, '[bot]')"
  group_of "${CALLER}" | grep -Fq "format('-{0}', github.run_id)"
}

@test "a newer run of the same key still cancels the older one" {
  [ "$(yq '.concurrency.cancel-in-progress' "${CALLER}")" = "true" ]
}
