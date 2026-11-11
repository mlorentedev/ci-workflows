---
tags: [spec, tasks, templates]
created: "2026-11-10"
id: "CI-007-fleet-pr-agent"
type: spec-tasks
status: active
owner: manu
---

# Tasks - CI-007-fleet-pr-agent

> TDD order. One task = one focused commit. Tick as you go. Reorder freely while spec is in `draft` state; freeze once you start `implementing`.
>
> **Inline markers** (optional, additive — borrowed from `github/spec-kit`, adapt-not-adopt per #141):
> - `[P]` — this task has **no dependency on another unchecked task**, so it is safe to run in parallel (fan out to a `Workflow`, or just batch). TDD chains (test → implement → refactor of the *same* behavior) are sequential and must NOT carry `[P]`; independent behaviors can.
> - `[AC<n>]` — this task helps satisfy **acceptance criterion #`<n>`** from `proposal.md`. Lets `/spec check` map coverage deterministically; omit it and the check falls back to semantic judgment.

## Setup

- [x] Spec merged (#63); fork 1 and fork 2 decided; v0.5.0 tagged 2026-11-11 (day T).
- [x] Adopter inventory taken 2026-11-11 (proposal.md, "Inventory for the kit").
- [x] Kit written: `kit/class-paragraph.txt` (byte-identical to the first paragraph of this repository's
      `extra_instructions`) and `kit/classification.json` (the block each registry gains).
- [ ] Fork 2b decided by the owner: where the guard that holds paragraph and registry together runs.
- [ ] Coordinated with the session opening the day-T Renovate and hygiene PRs: no file overlap
      (`renovate.json`, `.github/dependabot.yml`, `repo-hygiene.yml`, `scripts/check-lessons.sh`,
      `docs/lessons/**`). Re-check on T+1 before opening, with `gh pr list` in each adopter.

## Implementation (T+1, 2026-11-12, not before)

Per adopter, one draft PR from `chore/adopt-shared-pr-agent`, in its own worktree:

- [ ] [AC1] Replace `.github/workflows/pr-agent.yml` with `kit/pr-agent.yml`: hive's `pr-agent-shared.yml`
      shape, pinned to v0.5.0 (`04f2d0a…`). Carry over any trigger or input the old file had for a reason
      (read its comments first). In hive, delete both old files and keep only this caller.
- [ ] [AC2] No `The-PR-Agent/pr-agent` left in any workflow (`grep -r` in the worktree).
- [ ] [AC3] Trim `.pr_agent.toml` to what differs from the base, and put `kit/class-paragraph.txt` first in
      `extra_instructions`, byte for byte. In svqtriana.github.io, replace its existing backtick paragraph;
      its `scripts/check-harness.mjs` checks substrings `Class: <name>`, which the kit paragraph still contains.
- [ ] [AC3] Add `classification` from `kit/classification.json` to `harness/review-attestation.json`
      (svqtriana.github.io already has it: leave it, or align `why`).
- [ ] [AC3] The guard, as fork 2b decides. Not in the T+1 PRs if 2b is still open.
- [ ] Run the repository's own checks locally before pushing.

Then, in order:

- [ ] One dotfiles PR adds the twelve as `ci:` consumers of `PR_AGENT_ANTHROPIC_API_KEY` in
      `secrets/registry.yaml`, with the guard list in `tests/pr-agent-config.bats`, as dotfiles#3210 did.
      Its body links the twelve open drafts, which is what satisfies the consumer rule.
- [ ] Owner merges it and runs `dotf secrets sync ci` for the twelve.
- [ ] [AC4] `gh pr ready` four adopters at a time. Start the next four only once each of the previous
      four has a PR-Agent review and no other review is running in the fleet.
- [ ] Triage each PR (`## Review triage`); the owner merges (adopter workflows are always-human).

## Closing

- [ ] f1, f2 and f4 in `features.json` exit 0; f3's guard clause follows fork 2b.
- [ ] `verification.md` filled with the PR links and command outputs.
- [ ] Independent adversarial review before archive.

## Machine-readable features

This spec emits a sibling `features.json` (alongside this file) following [[pattern-feature-list-as-primitive]]. The JSON is the harness-facing contract: each acceptance criterion maps to ≥1 feature with `id`, `behavior`, `verification` (executable command), `state` (lifecycle), and `evidence` (harness-captured output).

**Pass-state gating:** the agent CANNOT write `"state": "passing"` — only the harness, after running `verification` and capturing exit code 0, may set that terminal state. Reviewers must reject PRs where features.json contains `passing` entries with empty `evidence`.

Minimal `features.json` skeleton (drop into `<repo>/specs/CI-007-fleet-pr-agent/features.json`):

```json
[
  {
    "id": "CI-007-fleet-pr-agent-f1",
    "behavior": "<one-line copy of an acceptance criterion>",
    "verification": "<single shell command; exit 0 means pass>",
    "state": "pending",
    "evidence": ""
  }
]
```
