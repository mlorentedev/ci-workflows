---
tags: [spec, verification]
created: "2026-11-04"
id: "CI-001-gate-and-changes"
type: spec-verification
status: active
owner: manu
---

# Verification - CI-001-gate-and-changes

## Evidence

- [x] Criterion 1. Commits `9483d7b` and `f62baab`. Tests: `gate.bats` ("passes when every need
      succeeded", "passes when a need was skipped…"); `changes.bats` ("a docs-only pull request reports
      only docs", "a code pull request reports its area").
- [x] Criterion 2. Commit `9483d7b`. Tests: `gate.bats` "fails on a failed need…", "fails on a cancelled
      need…", "fails when needs is empty…", "fails when needs is not a JSON object".
- [x] Criterion 3. Commit `f62baab`. Tests: `changes.bats` "a push / a schedule / a dispatch reports
      every area as changed".
- [x] Criterion 4. Commit `f62baab`. Test: `changes.bats` "paths-filter is pinned by full SHA…".
- [x] Criterion 5. The README sections `## changes` and `## gate`.

## Test status

- Test suite: `bats tests/` reports 57 of 57 ok. `actionlint` reports no findings.
- The command of every entry in `features.json` exits 0.
- Manual smoke test: none. A workflow runs neither composite yet. The first consumer is criterion 3 of
  issue #9, which this branch does not close.
- No regressions in the existing suite: none. `push-gate.bats`, `callers.bats`, `pr-agent-shape.bats`
  and `preflight-step.bats` all pass.

## Decisions made during implementation

- **One `areas` JSON output**, not one output per area. Composite outputs are declared statically, and
  the area names belong to the caller. Callers write `contains(fromJSON(...areas), '<area>')`.
- **paths-filter, not a `dotf` verb.** Issue #9 allows either. No verb exists, and ADR-001 decision 1
  would move change detection into `dotf` later.
- **A pull request whose filter produced no output fails.** Reporting `[]` there would skip every job
  and pass `gate`.

## Promotion candidates

- [x] Lesson for the repo's `docs/lessons/`? yes: docs/lessons/lesson-002-actionlint-does-not-read-composite-actions.md
- [x] ADR-worthy decision for the repo's `docs/adr/adr-XXX.md`? no: it applies ADR-001 decisions 3 and 4 and adds no new structural decision
- [x] New pattern candidate for `00_meta/patterns/`? no: one occurrence; it becomes a pattern if another repository's linter is found with the same blind spot

## Archive checklist

- [ ] `proposal.md` frontmatter set to `status: archived`
- [ ] Folder moved: `specs/CI-001-gate-and-changes/` -> `specs/archive/CI-001-gate-and-changes/`
- [ ] Bitácora board ticket for this spec moved to Done / closed with PR link (ADR-018)
- [ ] Promotions above executed (if any)
