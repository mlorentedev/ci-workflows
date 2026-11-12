---
tags: [spec, verification, templates]
created: "2026-11-06"
id: "CI-005-hygiene"
type: spec-verification
status: active
owner: manu
---

# Verification - CI-005-hygiene

## Evidence

Map every acceptance criterion from `proposal.md` to concrete proof (commit hash, test name, or observed behavior).

- [ ] AC1: pending.
- [x] AC2: `smoke-hygiene` on main, push run 43173027029 at `e8977f2`, job 131031182732, with dotf 0.79.0. The lessons step on this repository ended `outcome=success`. The step on `tests/fixtures/lessons/duplicate-number` ended `outcome=failure` with "lesson number 001 is used twice: …/lesson-001-first-fixture.md and …/lesson-001-same-number.md", and the job passed because the fixture failed naming the file.
- [ ] AC3: pending (dotf v0.80.0 carries fleet/sha-pin).
- [ ] AC4: GitHub side shown by the run above; Gitea pending (IDP-036 session).
- [ ] AC5: pending (adoption PRs).
- [ ] AC6: pending (dotfiles side).

## Test status

- Test suite: `<command> -> <output / coverage %>`
- Manual smoke test: what was exercised, what was observed
- No regressions in existing test suite: yes / no (if no, document)

## Decisions made during implementation

Brief log of non-obvious trade-offs or course corrections taken during the work. Routine choices belong in commit messages, not here.

-
-

## Promotion candidates

Answer each line `yes: <path>`, naming the file you promoted, or `no: <reason>`. `dotf spec archive` refuses a line left unanswered, a `no` without a reason, and a `yes` whose file does not exist; a `00_meta/` path is looked up in the vault.

- [ ] Lesson for the repo's `docs/lessons/`? <yes: path / no: reason>
- [ ] ADR-worthy decision for the repo's `docs/adr/adr-XXX.md`? <yes: path / no: reason>
- [ ] New pattern candidate for `00_meta/patterns/`? Only if this recurs in >1 project. <yes: path / no: reason>

## Archive checklist

- [ ] `proposal.md` frontmatter set to `status: archived`
- [ ] Folder moved: `specs/CI-005-hygiene/` -> `specs/archive/CI-005-hygiene/`
- [ ] Bitácora board ticket for this spec moved to Done / closed with PR link (ADR-018)
- [ ] Promotions above executed (if any)
