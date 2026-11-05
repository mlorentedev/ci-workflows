---
tags: [spec, tasks]
created: "2026-11-04"
id: "CI-002-release"
type: spec-tasks
status: active
owner: manu
---

# Tasks - CI-002-release

## Setup

- [x] Branch created from main: `feat/issue-15-release-please`
- [x] `proposal.md` is complete and acceptance criteria are testable
- [x] Settled before starting: secret name `RELEASE_TOKEN` (dotfiles#3156), bootstrap tag `v0.2.0` at
      `892309f`, `changelog-type: github`

## Implementation

- [x] [AC1] [AC2] [AC3] Write failing `tests/release-shape.bats` and `tests/fixtures/release-shape-bad.yml`
- [x] [AC1] [AC2] Add `.github/workflows/release.yml` to make the workflow rules pass
- [x] [AC3] Add `release-please-config.json` and `.release-please-manifest.json` to make the config rules pass
- [x] [AC4] Add `.github/workflows/release-please.yml`, this repository's caller
- [x] [AC4] Add `tests/release-callers.bats` with fixtures for dotfiles and pollex, and a bad caller
- [x] [AC5] README `## release` and AGENTS.md
- [x] Lesson 003: release-please simple writes no version file it does not find

## Closing

- [x] Criteria 1 to 4 are each covered by at least one bats test; criterion 5 by the grep in `features.json` f5
- [x] Criterion 6 is verified on the first run after merge (f6)
- [x] `bats tests/` passes
- [x] `actionlint` passes
- [x] No unrelated changes in the diff
- [x] `verification.md` filled in
- [x] PR opened referencing this spec folder
