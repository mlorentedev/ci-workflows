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

# Every class the registry declares is asked for, spelled as prefix + class (#59).
instructions_ask_for_every_class() {
  local registry="$1" toml="$2" prefix class
  prefix="$(jq -r '.classification.prefix // ""' "${registry}")"
  [ -n "${prefix// /}" ] || return 1
  [ "$(jq '.classification.classes | length' "${registry}")" -gt 0 ] || return 1
  while IFS= read -r class; do
    grep -qF "\"${prefix}${class}\"" "${toml}" || return 1
  done < <(jq -r '.classification.classes[]' "${registry}")
}

# PR-Agent is asked for the line; CodeRabbit writes its own severity format.
classifies_pr_agent_only() { jq -e '.classification.reviewers == ["github-actions"]' "$1" >/dev/null; }

@test "the instructions ask for every class the registry reads" {
  instructions_ask_for_every_class "${ATTESTATION}" "${TOML}"
  run ! instructions_ask_for_every_class "$(broken '.classification.classes += ["MINOR"]' "${ATTESTATION}")" "${TOML}"
  run ! instructions_ask_for_every_class "$(broken 'del(.classification)' "${ATTESTATION}")" "${TOML}"
  sed 's/"Class: THEORETICAL"/"Class: THEORETIC"/' "${TOML}" >"${BATS_TEST_TMPDIR}/pr_agent.toml"
  run ! instructions_ask_for_every_class "${ATTESTATION}" "${BATS_TEST_TMPDIR}/pr_agent.toml"
}

@test "only PR-Agent is held to the class line" {
  classifies_pr_agent_only "${ATTESTATION}"
  run ! classifies_pr_agent_only "$(broken '.classification.reviewers += ["coderabbitai"]' "${ATTESTATION}")"
}
