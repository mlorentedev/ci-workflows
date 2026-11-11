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

Thirteen repositories run PR-Agent. Inventory on 2026-11-10:

- Eleven run their own `pr-agent.yml`, 190 to 883 lines each, on `The-PR-Agent/pr-agent` at one of two SHAs:
  garsync, hive, iris, kubelab, leaving-denver, mail2markdown, pdf-modifier, pollex, svqtriana.github.io,
  ts-bridge, web, yt-metrics-cli. hive also runs the shared workflow beside its own (`pr-agent-shared.yml`);
  the comparison week for removing its old job ends on 2026-11-09 (thread main@macmini).
- dotfiles runs its own workflow on purpose: the shared one derives from it.
- ci-workflows calls the shared workflow by path (#51).
- Each repository holds its own `.pr_agent.toml`, 2 to 18 KB. Only dotfiles asks for the `Class:` line that
  the triage queue reads (#59 / #61 adds it here).

A fix to the review lane reaches one repository at a time, and the eleven copies drift.

## What

For each adopting repository, one PR that:

- Replaces its `pr-agent.yml` with a thin caller of `mlorentedev/ci-workflows/.github/workflows/pr-agent.yml`,
  pinned by full SHA with the tag as a comment. It has the same shape as hive's `pr-agent-shared.yml` and passes
  `NAN_API_KEY`, plus `PR_AGENT_ANTHROPIC_API_KEY` where the repository holds it.
- Trims its `.pr_agent.toml` to what differs from the base: its own instructions and ignores.
- Leaves its `review-attestation` registry as is.

Batches stay below NaN's five concurrent review slots (dotfiles#3188: eight pushes at once lost three reviews).
They are sequenced around the Renovate and hygiene adopter PRs that ci-workflows-34 opens in the same
repositories after v0.5.0, so no repository gets two adopter PRs on the same day.

## Out of scope

- dotfiles: it is the source the shared workflow derives from.
- New review behaviour. Any change to the shared workflow itself is its own PR in this repository.
- A fleet tool. `dotf fleet apply`, which #33 assumed, does not exist in dotf 0.79.0 (`unknown command
  "fleet"`); the PRs are opened one by one.

## Risks / open questions

Three forks for the owner to decide before any fleet PR opens:

1. **The Anthropic key in NaN-only repositories.** Decided (A), sync it to every adopter: the owner ran
   `dotf secrets sync ci ... PR_AGENT_ANTHROPIC_API_KEY` on six adopters on 2026-11-10. The secrets registry
   refused all six, correctly, because they are not consumers yet. Each adopter therefore needs, in order:
   - a dotfiles PR adding `ci:mlorentedev/<repo>` to the key's consumers. One PR can cover all twelve, as
     dotfiles#3210 did for this repository;
   - `dotf secrets sync ci` by the owner after it merges;
   - the adopter's PR here, whose first review then draws from the full pool.
   dotfiles#3290 is to derive each repository's CI secrets from the workflows it runs and report missing and
   excess ones. Until it lands, the consumer list is kept by hand.
2. **Where the `Class:` instruction lives.** PR-Agent (The-PR-Agent/pr-agent at efdde4a,
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
   in any order. Their size depends on fork 1:
   - The embedded pool spreads reviews over NaN and Haiku only where `PR_AGENT_ANTHROPIC_API_KEY` is present.
     Of the twelve adopters only hive and kubelab hold it.
   - The other ten draw NaN alone and share its five concurrent slots. Eight pushes at once lost three reviews
     in dotfiles#3188.
   - With (A), one batch is enough. With (B), batches of four.

## Acceptance criteria

- [ ] Every repository that runs PR-Agent, except dotfiles, calls the shared workflow pinned by full SHA.
- [ ] No adopter keeps a copy of the review steps (`The-PR-Agent/pr-agent` appears in no adopter's workflows).
- [ ] Each adopter's `.pr_agent.toml` holds only what differs from the base, and asks for the `Class:` line
      in the way fork 2 decides.
- [ ] Every adopter PR gets a PR-Agent review from the shared workflow. No batch loses a review to NaN's slot
      limit.

## References

- #33, #51 (self-review), #59 / #61 (classification), dotfiles#3290 (CI secrets derived from workflows), dotfiles#3188 (NaN slots), dotfiles#3212 (weights)
- hive `.github/workflows/pr-agent-shared.yml`, the caller shape to copy
