---
tags: [spec, tasks]
created: "2026-11-11"
id: "CI-011-macos-smoke"
type: spec-tasks
status: active
owner: manu
---

# Tasks - CI-011-macos-smoke

## Setup

- [x] Branch created from main: `feat/issue-71-macos-smoke`
- [x] `proposal.md` is complete and acceptance criteria are testable
- [x] No open questions left in `proposal.md` "Risks / open questions"

## Implementation

- [x] [AC1] [AC3] Failing bats test: every toolchain smoke is a `fail-fast: false` matrix over `ubuntu-latest` and `macos-latest`, runs on `${{ matrix.os }}`, and keeps its `toolchains` condition
- [x] [AC2] Failing bats test: the node smoke passes `playwright: "true"`, installs Chromium and checks the browsers path; the fixture's lockfile pins `@playwright/test`
- [x] [AC2] Add `@playwright/test` 1.64.1 to the node fixture and regenerate its lockfile
- [x] [AC1] [AC2] [AC3] Turn the four smokes into matrices in `lint.yml`, with Report steps written for bash 3.2
- [x] [AC1] Push, then rerun each macOS leg and record the job ids that report a hit

## Closing

- [x] Every acceptance criterion from `proposal.md` is covered by at least one test
- [x] Every acceptance criterion has a matching entry in `features.json`
- [x] Lint passes (`actionlint`, `shellcheck` via bats)
- [x] No unrelated changes in the diff
- [x] `verification.md` filled in
- [x] PR opened referencing this spec folder
