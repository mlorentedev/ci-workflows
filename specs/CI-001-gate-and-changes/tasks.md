---
tags: [spec, tasks]
created: "2026-11-04"
id: "CI-001-gate-and-changes"
type: spec-tasks
status: active
owner: manu
---

# Tasks - CI-001-gate-and-changes

## Setup

- [x] Branch created from main: `feat/issue-9-gate-changes`
- [x] `proposal.md` is complete and acceptance criteria are testable
- [x] Open questions are either resolved or deferred to issue #9 criterion 3 (Gitea), which this branch does not close

## Implementation

- [x] [P] [AC1] [AC2] Write failing `tests/gate.bats`: success and skipped pass; failure, cancelled, empty and invalid JSON fail with a named cause
- [x] [AC1] [AC2] Add `.github/actions/gate/action.yml` to make it pass
- [x] [P] [AC1] [AC3] [AC4] Write failing `tests/changes.bats`: pull request areas pass through; push, schedule and dispatch report every area; inline and file maps; missing `yq` fails; SHA pin
- [x] [AC1] [AC3] [AC4] Add `.github/actions/changes/action.yml` to make it pass
- [x] Shellcheck both composites' scripts from bats, since actionlint only reads `.github/workflows/`
- [x] [AC5] README sections for `changes` and `gate`

## Closing

- [x] Every acceptance criterion from `proposal.md` is covered by at least one test
- [x] Every acceptance criterion has a matching entry in `features.json`
- [x] `bats tests/` passes
- [x] `actionlint` passes
- [x] No unrelated changes in the diff
- [x] `verification.md` filled in
- [x] PR opened referencing this spec folder (#17)
