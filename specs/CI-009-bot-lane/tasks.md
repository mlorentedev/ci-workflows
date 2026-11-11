---
tags: [spec, tasks]
created: "2026-11-11"
id: "CI-009-bot-lane"
type: spec-tasks
status: active
owner: manu
---

# Tasks - CI-009-bot-lane

> TDD order. One task = one focused commit. `[AC<n>]` maps a task to an acceptance criterion in `proposal.md`.

## Setup

- [x] Branch `docs/issue-13-bot-lane-spec`, proposal written
- [ ] Owner decisions from the proposal's Risks: release age, merging token, bot identity, production paths, opt-in file
- [ ] The dotf commands (`declare-unreviewed --diff lane`, `verify-pin-bump`, dotfiles#3317) released (blocks PR 2)

## Implementation

PR 1, the report half (needs no new dotf command):

- [ ] [AC2] Write `tests/bot-lane.bats` with failing tests: a red head commit opens one issue, a second red run updates it, a green run closes it, a run in progress changes nothing (stub `gh`). Then implement.
- [ ] Failing test that the workflow declares only the permissions the report needs, and has no merge job yet. Then implement.
- [ ] Smoke job `smoke-bot-lane` in `lint.yml`, listed in `gate.needs` and asserted there by a test, as `smoke-hygiene` is.

PR 2, unreviewed and merge (after the dotf release):

- [ ] [AC1] Failing tests that a `dependabot[bot]` or release-please pull request touching a workflow is declared unreviewed with the lane's reason, and that a human pull request on a `renovate/` branch with the preset's labels is not. Then implement.
- [ ] [AC4] `bot-lane/merge-class.json`, with failing tests that fail on a widened class and on a changed merge condition or head-commit pin. Then implement.
- [ ] [AC3] Failing tests for an accepted digest bump, an extra hunk, a SHA that does not match its tag, a floating tag, a change to the caller's lane workflow, a production path, a downgrade, a rename or mode change, a retargeted base, and a release younger than the minimum age or missing its date; and that the merging job runs on `workflow_run` and a schedule only, never `pull_request` or `pull_request_target`, and checks out no PR code. Then implement.
- [ ] [AC5] Failing test that the merge job cannot run for a release-please pull request. Then implement.
- [ ] [AC6] README section; caller fixtures for two repositories under `tests/fixtures/bot-lane/`, one with production paths. Not under `tests/fixtures/callers/`, which `tests/callers.bats` reads as pr-agent callers only.
