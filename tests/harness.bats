#!/usr/bin/env bats
#
# The reviewer pool and the review-attestation registry (#28). dotf reads both;
# these tests hold the invariants this repository relies on, not the members,
# which follow dotfiles. Each rule also runs against a copy that breaks it.

bats_require_minimum_version 1.5.0

ROOT="${BATS_TEST_DIRNAME}/.."
POOL="${ROOT}/harness/reviewer-pool.json"
ATTESTATION="${ROOT}/harness/review-attestation.json"

# The reviewer must not be the implementer, and Claude implements here: an
# Anthropic member signs only beside or after another vendor, never first.
no_anthropic_first_signer() {
  jq -e '[.pool[] | select(.vendor == "anthropic" and ((.signs // "first") == "first"))] | length == 0' "$1" >/dev/null
}

# A first signer from another vendor must exist, or no review can be signed.
has_non_anthropic_first_signer() {
  jq -e '[.pool[] | select(.vendor != "anthropic" and ((.signs // "first") == "first"))] | length > 0' "$1" >/dev/null
}

# The launcher passes each of these explicitly; a pin that relies on a default is not a pin.
every_member_pinned() {
  jq -e 'all(.pool[]; (.id // "") != "" and (.runner // "") != "" and (.model // "") != "" and (.vendor // "") != "")' "$1" >/dev/null
}

# release-please writes the manifest and CHANGELOG.md only (lesson 003: no version file).
release_exempt_matches_release_please() {
  jq -e '.exempt.signatures[] | select(.name == "release-please") | .files | sort == [".release-please-manifest.json", "CHANGELOG.md"]' "$1" >/dev/null
}

# The heading every triage comment in this repository is written under.
triage_marker_is_review_triage() { jq -e '.triage.marker == "## Review triage"' "$1" >/dev/null; }

broken() { jq "$1" "$2" >"${BATS_TEST_TMPDIR}/broken.json" && echo "${BATS_TEST_TMPDIR}/broken.json"; }

@test "no Anthropic member signs a review first" {
  no_anthropic_first_signer "$POOL"
  run ! no_anthropic_first_signer "$(broken '(.pool[] | select(.vendor == "anthropic")) |= del(.signs)' "$POOL")"
}

@test "another vendor can sign first" {
  has_non_anthropic_first_signer "$POOL"
  run ! has_non_anthropic_first_signer "$(broken '.pool |= map(select(.vendor == "anthropic"))' "$POOL")"
}

@test "every pool member names its id, runner, model and vendor" {
  every_member_pinned "$POOL"
  run ! every_member_pinned "$(broken '.pool[0] |= del(.model)' "$POOL")"
}

@test "the release PR is exempt for exactly the files release-please writes" {
  release_exempt_matches_release_please "$ATTESTATION"
  run ! release_exempt_matches_release_please "$(broken '.exempt.signatures[0].files += ["version.txt"]' "$ATTESTATION")"
}

@test "triage is recorded under ## Review triage" {
  triage_marker_is_review_triage "$ATTESTATION"
  run ! triage_marker_is_review_triage "$(broken '.triage.marker = "## Triage"' "$ATTESTATION")"
}

TOML="${ROOT}/.pr_agent.toml"

# The classes the registry reads and the classes the active instructions ask
# for are the same set (#59). Only the parsed extra_instructions value counts, so
# a class left behind in a TOML comment does not.
registry_classes() {
  jq -er '.classification.classes
    | if type == "array" and length > 0 and all(.[]; type == "string") then .[] else error("no classes") end' "$1" | sort -u
}
instruction_classes() {
  local prefix="$1" toml="$2" text
  text="$(yq -p toml -oy '.pr_reviewer.extra_instructions // ""' "${toml}")" || return 1
  grep -oE "\"${prefix}[A-Z]+\"" <<<"${text}" | sed -E "s/^\"${prefix}//; s/\"$//" | sort -u
}
instructions_ask_for_every_class() {
  local registry="$1" toml="$2" prefix expected actual
  prefix="$(jq -r '.classification.prefix // ""' "${registry}")"
  [ -n "${prefix// /}" ] || return 1
  expected="$(registry_classes "${registry}")" || return 1
  actual="$(instruction_classes "${prefix}" "${toml}")" || return 1
  [ "${expected}" = "${actual}" ]
}

# PR-Agent is asked for the line; CodeRabbit writes its own severity format.
classifies_pr_agent_only() { jq -e '.classification.reviewers == ["github-actions"]' "$1" >/dev/null; }

@test "the instructions ask for exactly the classes the registry reads" {
  instructions_ask_for_every_class "${ATTESTATION}" "${TOML}"
  run ! instructions_ask_for_every_class "$(broken '.classification.classes += ["MINOR"]' "${ATTESTATION}")" "${TOML}"
  run ! instructions_ask_for_every_class "$(broken 'del(.classification)' "${ATTESTATION}")" "${TOML}"
  run ! instructions_ask_for_every_class "$(broken '.classification.classes = "REAL"' "${ATTESTATION}")" "${TOML}"
  local t="${BATS_TEST_TMPDIR}/pr_agent.toml"
  sed 's/"Class: THEORETICAL"/"Class: THEORETIC"/' "${TOML}" >"${t}"
  run ! instructions_ask_for_every_class "${ATTESTATION}" "${t}"
  sed 's/"Class: SPECULATIVE"/"Class: SPECULATIVE" or "Class: MINOR"/' "${TOML}" >"${t}"
  run ! instructions_ask_for_every_class "${ATTESTATION}" "${t}"
  { printf '# "Class: REAL", "Class: THEORETICAL", "Class: SPECULATIVE"\n'; sed '/^extra_instructions/,/^"""$/d' "${TOML}"; } >"${t}"
  run ! instructions_ask_for_every_class "${ATTESTATION}" "${t}"
}

@test "only PR-Agent is held to the class line" {
  classifies_pr_agent_only "${ATTESTATION}"
  run ! classifies_pr_agent_only "$(broken '.classification.reviewers += ["coderabbitai"]' "${ATTESTATION}")"
}
