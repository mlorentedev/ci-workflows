#!/usr/bin/env bats
#
# The reviewer pool and the review-attestation registry (#28). dotf reads both;
# these tests hold the invariants this repository relies on, not the members,
# which follow dotfiles. Each rule also runs against a copy that breaks it.

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
  ! no_anthropic_first_signer "$(broken '(.pool[] | select(.vendor == "anthropic")) |= del(.signs)' "$POOL")"
}

@test "another vendor can sign first" {
  has_non_anthropic_first_signer "$POOL"
  ! has_non_anthropic_first_signer "$(broken '.pool |= map(select(.vendor == "anthropic"))' "$POOL")"
}

@test "every pool member names its id, runner, model and vendor" {
  every_member_pinned "$POOL"
  ! every_member_pinned "$(broken '.pool[0] |= del(.model)' "$POOL")"
}

@test "the release PR is exempt for exactly the files release-please writes" {
  release_exempt_matches_release_please "$ATTESTATION"
  ! release_exempt_matches_release_please "$(broken '.exempt.signatures[0].files += ["version.txt"]' "$ATTESTATION")"
}

@test "triage is recorded under ## Review triage" {
  triage_marker_is_review_triage "$ATTESTATION"
  ! triage_marker_is_review_triage "$(broken '.triage.marker = "## Triage"' "$ATTESTATION")"
}
