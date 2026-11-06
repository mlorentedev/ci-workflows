---
tags: [spec, tasks, templates]
created: "2026-11-05"
id: "CI-004-toolchain-setup"
type: spec-tasks
status: active
owner: manu
---

# Tasks - CI-004-toolchain-setup

> TDD order. One task = one focused commit. Tick as you go. Reorder freely while spec is in `draft` state; freeze once you start `implementing`.
>
> **Inline markers** (optional, additive — borrowed from `github/spec-kit`, adapt-not-adopt per #141):
> - `[P]` — this task has **no dependency on another unchecked task**, so it is safe to run in parallel (fan out to a `Workflow`, or just batch). TDD chains (test → implement → refactor of the *same* behavior) are sequential and must NOT carry `[P]`; independent behaviors can.
> - `[AC<n>]` — this task helps satisfy **acceptance criterion #`<n>`** from `proposal.md`. Lets `/spec check` map coverage deterministically; omit it and the check falls back to semantic judgment.

## Setup

- [x] Branch created from main: `feat/issue-10-setup-node`
- [x] `proposal.md` is complete and acceptance criteria are testable
- [x] No open question blocks the code. The Gitea cache question is answered by the pilot (AC4), and the composite must not depend on the answer.

## Implementation

Four pull requests, one per composite, in this order:
1. `setup-node`, which also brings the shared smoke harness;
2. `setup-python-poetry`;
3. `setup-python-uv`;
4. `setup-go-lint`.

The tasks below are PR 1. PRs 2–4 get their tasks once PR 1 has merged, reusing its harness.

### PR 1: `setup-node`

Pins:
- `actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0`
- `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0`

The interface of `.github/actions/setup-node/action.yml`:
- **Inputs.**
  - `version`, default empty.
  - `version-file`, default `.nvmrc`.
  - `working-directory`, default `.`.
  - `playwright`, default `false`.
- **Outputs.**
  - `cache-hit` and `cache-primary-key`, from `actions/setup-node`'s npm cache.
  - `playwright-cache-hit`.
- **Steps.**
  - `resolve` (bash) publishes either `version` or `file`. It fails when both are empty, or when the file is missing.
  - `setup` (`actions/setup-node`) runs with `cache: npm` and `cache-dependency-path: <working-directory>/package-lock.json`.
  - `playwright-version` (bash, only when `playwright == 'true'`) reads the `@playwright/test` or `playwright` version from `package-lock.json`.
  - `playwright` (`actions/cache`) caches `~/.cache/ms-playwright`, keyed on `playwright-${runner.os}-${runner.arch}-<version>`.
- **What stays with the caller.** The composite installs no packages and no browsers: the caller runs `npm ci`, and runs `npx playwright install --with-deps` when `playwright-cache-hit != 'true'`.

Tasks:

- [ ] [AC1] Write `tests/setup-node.bats` with failing tests:
  - the input defaults read from `action.yml`;
  - the outputs map to the right steps;
  - the steps run under `bash`;
  - each third-party `uses:` is pinned by a 40-hex SHA with its tag as a comment.

  Run `bats tests/setup-node.bats`. Expected: FAIL, because `action.yml` is missing.
- [ ] [AC1] Write `.github/actions/setup-node/action.yml` with the interface above. Expected: those tests pass.
- [ ] [AC2] Add failing tests that run the `resolve` script the way `changes.bats` runs its steps:
  - a version input publishes `version`;
  - a present version file publishes `file`;
  - an empty version and a missing file fail with a message naming both.
- [ ] [AC2] Implement `resolve`. Expected: the tests pass.
- [ ] [AC5] Add failing tests that the Playwright cache key contains `runner.os` and `runner.arch` and the Playwright version, and that the cache step runs only when `playwright == 'true'`. Then implement.
- [ ] [AC2] Add tests that `playwright-version` reads the version from a fixture lockfile and fails when neither package is in it. Then implement.
- [ ] [AC3] Add the fixture `tests/fixtures/toolchains/node/`, holding `.nvmrc`, a `package.json` with one tiny dependency, and its `package-lock.json`. The cache needs something to store.
- [ ] [AC3] In `lint.yml`:
  - a `toolchains` area in `changes` covering `.github/actions/setup-*/**` and `tests/fixtures/toolchains/**`;
  - a `smoke-setup-node` job behind it, which uses `./.github/actions/setup-node` (this checkout, on purpose), runs `npm ci` in the fixture, and prints `cache-hit` and `cache-primary-key`;
  - the job added to `gate`'s `needs`.

  Expected: actionlint clean, and the `callers`/shape tests pass.
- [ ] [AC1] Extend `tests/composites-shellcheck.bats`'s minimum step count for the new `run:` steps. Expected: the suite passes.
- [ ] [AC3] After merge, record in `verification.md`:
  - the push run on `main` that warmed the cache (`cache-hit=false`);
  - the next run that read it (`cache-hit=true`, with a `cache-primary-key` holding the platform and arch).
- [ ] [AC4] Gitea pilot: imagesensortool's CI uses `setup-node` at a pinned SHA. Record whether the cache hits there or degrades with the job still green. A missing cache server becomes a kubelab ticket.
- [ ] README: a `## setup-node` section with the interface, the caller's `npm ci` and Playwright install, and the Gitea result.

## Closing

- [ ] Every acceptance criterion from `proposal.md` is covered by at least one test or recorded run
- [ ] Every acceptance criterion has a `features.json` entry with a non-vacuous verification command
- [ ] `bats tests/` and `actionlint` pass
- [ ] No unrelated changes in the diff
- [ ] `verification.md` filled in
- [ ] PR opened referencing this spec folder

## Machine-readable features

This spec emits a sibling `features.json` (alongside this file) following [[pattern-feature-list-as-primitive]]. The JSON is the harness-facing contract: each acceptance criterion maps to ≥1 feature with `id`, `behavior`, `verification` (executable command), `state` (lifecycle), and `evidence` (harness-captured output).

**Pass-state gating:** the agent CANNOT write `"state": "passing"` — only the harness, after running `verification` and capturing exit code 0, may set that terminal state. Reviewers must reject PRs where features.json contains `passing` entries with empty `evidence`.

Minimal `features.json` skeleton (drop into `<repo>/specs/CI-004-toolchain-setup/features.json`):

```json
[
  {
    "id": "CI-004-toolchain-setup-f1",
    "behavior": "<one-line copy of an acceptance criterion>",
    "verification": "<single shell command; exit 0 means pass>",
    "state": "pending",
    "evidence": ""
  }
]
```
