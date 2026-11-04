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

- [ ] [P] [AC1] [AC2] Write failing `tests/gate.bats`: success and skipped pass; failure, cancelled, empty and invalid JSON fail with a named cause
- [ ] [AC1] [AC2] Add `.github/actions/gate/action.yml` to make it pass
- [ ] [P] [AC1] [AC3] [AC4] Write failing `tests/changes.bats`: pull request areas pass through; push, schedule and dispatch report every area; inline and file maps; missing `yq` fails; SHA pin
- [ ] [AC1] [AC3] [AC4] Add `.github/actions/changes/action.yml` to make it pass
- [ ] Shellcheck both composites' scripts from bats, since actionlint only reads `.github/workflows/`
- [ ] [AC5] README sections for `changes` and `gate`

## Closing

- [ ] Every acceptance criterion from `proposal.md` is covered by at least one test
- [ ] Every acceptance criterion has a matching entry in `features.json`
- [ ] `bats tests/` passes
- [ ] `actionlint` passes
- [ ] No unrelated changes in the diff
- [ ] `verification.md` filled in
- [ ] PR opened referencing this spec folder
