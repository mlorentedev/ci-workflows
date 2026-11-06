---
tags: [spec, tasks, templates]
created: "2026-11-05"
id: "CI-005-pages"
type: spec-tasks
status: active
owner: manu
---

# Tasks - CI-005-pages

## Setup

- [x] Branch from main: `feat/issue-32-pages`
- [x] `proposal.md` complete, criteria testable; the five consumers read before writing (hive, pdf-modifier, pollex, ts-bridge, yt-metrics-cli)

## Implementation

- [x] [AC1] [AC2] `tests/pages-shape.bats` and `fixtures/pages-shape-bad.yml`, failing with no workflow
- [x] [AC1] [AC2] `.github/workflows/pages.yml`, with the pins the consumers already hold, checked against their tags
- [x] [AC3] `tests/pages-callers.bats`, the hive and ts-bridge fixtures and `fixtures/pages-caller-shape-bad.yml`
- [x] [AC4] README `## pages`

## After merge

- [ ] [AC5] Release, then migrate one consumer in its own PR and record its deploy here
