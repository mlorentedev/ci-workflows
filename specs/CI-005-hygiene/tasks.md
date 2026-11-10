---
tags: [spec, tasks, templates]
created: "2026-11-06"
id: "CI-005-hygiene"
type: spec-tasks
status: active
owner: manu
---

# Tasks - CI-005-hygiene

> TDD order. One task = one focused commit. Tick as you go. Reorder freely while spec is in `draft` state; freeze once you start `implementing`.
>
> **Inline markers** (optional, additive — borrowed from `github/spec-kit`, adapt-not-adopt per #141):
> - `[P]` — this task has **no dependency on another unchecked task**, so it is safe to run in parallel (fan out to a `Workflow`, or just batch). TDD chains (test → implement → refactor of the *same* behavior) are sequential and must NOT carry `[P]`; independent behaviors can.
> - `[AC<n>]` — this task helps satisfy **acceptance criterion #`<n>`** from `proposal.md`. Lets `/spec check` map coverage deterministically; omit it and the check falls back to semantic judgment.

## Setup

- [x] Branch created from main: `feat/issue-31-hygiene-composite`
- [x] `proposal.md` is complete and acceptance criteria are testable
- [x] No open question blocks the code: option A chosen 2026-11-09; the pinned-actions check waits for dotfiles#3147

## Implementation

PR 1, the composite (this branch):

- [x] [AC1] Write `tests/hygiene.bats` with failing tests: the inputs (`dotf-version`, `lessons`, `lessons-dir`) and no input for an absent check; only bash `run:` steps, no `gh` and no token; `install` fetches `dotf_<v>_linux_<arch>.tar.gz` with a stub `curl`, fails on a tampered archive, on a `checksums.txt` that does not list it, on a missing release, and on a non-Linux runner, naming it.
- [x] [AC1] Write `.github/actions/hygiene/action.yml`. Expected: those tests pass.
- [x] [AC2] Add failing tests that the `lessons` step runs `dotf lessons fmt --check --dir <workspace>/<lessons-dir>`, only when `lessons == 'true'`, and fails when dotf does. Then implement.
- [x] [AC2] Add the fixtures `tests/fixtures/lessons/clean/` and `tests/fixtures/lessons/duplicate-number/`, both in dotf's canonical form.
- [x] [AC2] In `lint.yml`: a `hygiene` area in `changes` (the composite, the fixtures, `docs/lessons/**`), a `smoke-hygiene` job that runs the composite on this repository and on the duplicate fixture, and fails unless the fixture fails naming `lesson-001-same-number.md`; `gate` needs it.
- [x] [AC1] Raise `tests/composites-shellcheck.bats`'s minimum step count for the two new `run:` steps.
- [x] README: a `## hygiene` section.
- [ ] [AC2] After merge, record the `smoke-hygiene` run on main in `verification.md`.

Adoption, one PR per repository, in batches of 4 (dotfiles#3188), after a tag carries the composite:

- [ ] Before each PR, grep the repository for readers of `docs/lessons/_index.md` (hive's code, kubelab's tests) and for pointer stubs that link it, and change them in the same PR.
- [ ] [AC5] Each PR runs `dotf lessons fmt`, deletes `_index.md` and `check-lessons.sh`, and replaces the lessons step of `repo-hygiene.yml` with the composite at a pinned SHA. `check-actions-pinned.sh` stays until dotfiles#3147.
- [ ] [AC4] Gitea: one Gitea repository runs the composite (owned by the IDP-036 session); record the run here.

After dotfiles#3147:

- [ ] [AC3] Add a `pinned-actions` input running the `dotf lint` SHA-pin rule, with a fixture pinned by tag that fails naming the line.
- [ ] [AC5] Adopters delete `check-actions-pinned.sh`.
- [ ] [AC6] `dotf lint` reports a repository that still carries a vendored script (dotfiles side).

## Closing

- [ ] Every acceptance criterion from `proposal.md` is covered by at least one test
- [ ] Every acceptance criterion has a matching entry in `features.json` (see below) with a non-vacuous verification command
- [ ] Type checks pass
- [ ] Lint passes
- [ ] No unrelated changes in the diff (no scope creep)
- [ ] `verification.md` filled in
- [ ] PR opened referencing this spec folder

## Machine-readable features

This spec emits a sibling `features.json` (alongside this file) following [[pattern-feature-list-as-primitive]]. The JSON is the harness-facing contract: each acceptance criterion maps to ≥1 feature with `id`, `behavior`, `verification` (executable command), `state` (lifecycle), and `evidence` (harness-captured output).

**Pass-state gating:** the agent CANNOT write `"state": "passing"` — only the harness, after running `verification` and capturing exit code 0, may set that terminal state. Reviewers must reject PRs where features.json contains `passing` entries with empty `evidence`.

Minimal `features.json` skeleton (drop into `<repo>/specs/CI-005-hygiene/features.json`):

```json
[
  {
    "id": "CI-005-hygiene-f1",
    "behavior": "<one-line copy of an acceptance criterion>",
    "verification": "<single shell command; exit 0 means pass>",
    "state": "pending",
    "evidence": ""
  }
]
```
