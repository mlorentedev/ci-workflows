---
id: "CI-007-fleet-pr-agent"
type: spec
status: draft # draft | implementing | verifying | archived
created: "2026-11-10"
issue: "mlorentedev/ci-workflows#33"   # repo#NNN — GitHub issue / Project item that tracks this spec
tags: [spec, proposal, ci, pr-agent, fleet]
template_version: "1.0"
owner: manu
---

# CI-007-fleet-pr-agent

## Why

<!-- from issue #33: chore: adopt the shared pr-agent workflow across the fleet -->

Fourteen repositories run PR-Agent. Inventory on 2026-11-10:

- Twelve run their own `pr-agent.yml`, 190 to 883 lines each, on `The-PR-Agent/pr-agent` at one of two SHAs:
  garsync, hive, iris, kubelab, leaving-denver, mail2markdown, pdf-modifier, pollex, svqtriana.github.io,
  ts-bridge, web, yt-metrics-cli. hive also runs the shared workflow beside its own (`pr-agent-shared.yml`);
  the comparison week for removing its old job ends on 2026-11-09 (thread main@macmini).
- dotfiles runs its own workflow on purpose: the shared one derives from it.
- ci-workflows calls the shared workflow by path (#51).
- Each repository holds its own `.pr_agent.toml`, 2 to 18 KB. Only dotfiles asks for the `Class:` line that
  the triage queue reads (#61 added it here).

A fix to the review lane reaches one repository at a time, and the twelve copies drift.

## What

For each adopting repository, one PR from the branch `chore/adopt-shared-pr-agent` that:

- Replaces its `pr-agent.yml` with a thin caller of `mlorentedev/ci-workflows/.github/workflows/pr-agent.yml`,
  pinned by full SHA with the tag as a comment. It has the same shape as hive's `pr-agent-shared.yml` and passes
  `NAN_API_KEY`, plus `PR_AGENT_ANTHROPIC_API_KEY` where the repository holds it.
- Trims its `.pr_agent.toml` to what differs from the base: its own instructions and ignores, plus the class
  paragraph fork 2 decides, byte-identical in every adopter and rendered from one template.
- Adds or updates `harness/review-attestation.json` with the `classification` block this repository carries
  (prefix `Class: `, classes REAL, THEORETICAL and SPECULATIVE, reviewers `["github-actions"]`), and the test
  that holds the paragraph and the registry together, as #61 does here. Without the registry the test has
  nothing to compare against.

Batches stay below NaN's five concurrent review slots (dotfiles#3188: eight pushes at once lost three reviews).
They are sequenced around the Renovate and hygiene adopter PRs that ci-workflows-34 opens in the same
repositories after v0.5.0, so no repository gets two adopter PRs on the same day.

## Out of scope

- dotfiles: it is the source the shared workflow derives from.
- New review behaviour. Any change to the shared workflow itself is its own PR in this repository.
- A fleet tool. `dotf fleet apply`, which #33 assumed, does not exist in dotf 0.79.0 (`unknown command
  "fleet"`); the PRs are opened one by one.

## Risks / open questions

Three forks for the owner to decide before any fleet PR opens. Forks 1 and 2 are decided.

1. **The Anthropic key in NaN-only repositories.** Decided (A), sync it to every adopter: the owner ran
   `dotf secrets sync ci ... PR_AGENT_ANTHROPIC_API_KEY` on six adopters on 2026-11-10. The secrets registry
   refused all six, correctly, because they are not consumers yet. dotfiles declares the key only for a
   repository whose workflow reads it or whose adopting PR is open: "a credential synced where nothing reads
   it only widens the surface" (tests/pr-agent-config.bats). So on T+1, in order:
   - the twelve adopter PRs open as drafts, so no review runs yet;
   - one dotfiles PR adds all twelve as consumers, as dotfiles#3210 did for this repository. It satisfies the
     rule, because every adopting PR is open;
   - after it merges, the owner runs `dotf secrets sync ci`;
   - the adopter PRs are marked ready, and each first review draws from the full pool.
   dotfiles#3290 is to derive each repository's CI secrets from the workflows it runs and report missing and
   excess ones. Until it lands, the consumer list is kept by hand.
2. **Where the `Class:` instruction lives.** Decided (A) on 2026-11-11. The class line is a contract between
   what the reviewer writes and what the triage queue reads from the same repository's registry; only (A) puts
   both halves in one PR, where a test holds them together. (C) loses the line silently in any repository that
   sets its own `extra_instructions`, and (B) would block T+1 on a dotf change outside this spec. PR-Agent (The-PR-Agent/pr-agent at efdde4a,
   `git_providers/utils.py`) puts env vars at the top of its precedence: `_reapply_env_overrides` replays them
   after every file layer. It merges files key by key.
   - Setting `PR_REVIEWER.EXTRA_INSTRUCTIONS` in the shared workflow would therefore erase every repository's
     own instructions.
   - A base file loaded through `CONFIG.EXTRA_CONFIG_URL` sits below the repository file. But a repository
     that sets its own `extra_instructions` replaces the base string whole, so the class line is lost there too.
   - Choices:
     - (A) Each repository's minimal `.pr_agent.toml` carries the class paragraph, guarded by a test like #61's.
     - (B) dotf composes the base and the repository's instructions into one value the workflow passes.
     - (C) A base file through `EXTRA_CONFIG_URL`, with repositories putting their extras under a different key.
   - Before (C) is chosen, check that the image the shared workflow pins (`pragent/pr-agent@sha256:80edef7…`)
     supports `EXTRA_CONFIG_URL`.
3. **Batch order and size.** ci-workflows-34 opens every Renovate and hygiene adopter PR on day T, when
   v0.5.0 is tagged; the owner chose not to stagger (2026-11-10). The adopter PRs here therefore start on T+1,
   in any order.
   - The embedded pool spreads reviews over NaN and Haiku only where `PR_AGENT_ANTHROPIC_API_KEY` is present.
     Today only hive and kubelab hold it; fork 1 extends it to all twelve.
   - A weighted draw lowers the expected load on NaN but does not bound it: twelve reviews can still send more
     than five to NaN at once. Eight pushes at once lost three reviews in dotfiles#3188.
   - The PRs open as drafts, so the review starts when each is marked ready. They are marked ready four at a
     time, and the next four only once the previous reviews have posted and no other review is running in the
     same window.

## Acceptance criteria

- [ ] Every adopting repository (the twelve in Why) calls the shared workflow pinned by full SHA.
- [ ] No adopter keeps a copy of the review steps (`The-PR-Agent/pr-agent` appears in no adopter's workflows).
- [ ] Each adopter's `.pr_agent.toml` holds only what differs from the base, and asks for the `Class:` line
      in the paragraph fork 2 (A) decides, guarded by a test against its own registry.
- [ ] Every adopter PR gets a PR-Agent review from the shared workflow. No batch loses a review to NaN's slot
      limit.

## References

- #33, #51 (self-review), #59 / #61 (classification), dotfiles#3290 (CI secrets derived from workflows), dotfiles#3188 (NaN slots), dotfiles#3212 (weights)
- hive `.github/workflows/pr-agent-shared.yml`, the caller shape to copy
