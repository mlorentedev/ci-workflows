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
- [ ] AC3: the `pinned-actions` input and its smoke are in place, on dotf 0.81.0; ticked once the `smoke-hygiene` run on main is recorded here.
- [ ] AC4: GitHub side shown by the run above; Gitea pending (IDP-036 session).
- [ ] AC5: lessons half done, pinned-actions half pending. Ten adopters run the composite's lessons check at `2355330` (v0.6.0) and carry no `scripts/check-lessons.sh` and no committed `docs/lessons/_index.md` on their default branch. Each merged push ran `Repo hygiene` green:

  | Adopter | PR | Merge | Repo hygiene run |
  |---|---|---|---|
  | pdf-modifier | #239 | `acc5b5c` | 43308384451 |
  | pollex | #131 | `eb19d7e` | 43308420494 |
  | yt-metrics-cli | #121 | `06c5a8e` | 43308699783 |
  | mail2markdown | #34 | `85c0482` | 43308323156 |
  | iris | #64 | `c2d3722` | 43308089242 |
  | hive | #582 | `61202d6` | 43242348268 |
  | garsync | #165 | `6dff638` | 43308004887 |
  | ts-bridge | #755 | `d923fbc` | 43337177847 |
  | web | #661 | `0a69c87` | 43308578791 |
  | svqtriana.github.io | #43 | `b7921d2` | 43308483074 |

  kubelab is excluded by the owner's decision (ci-workflows#31): its application code and tests read the lesson indexes, so it needs its own spec first. Every adopter still carries `scripts/check-actions-pinned.sh`; it goes once the composite has the pinned-actions input (AC3, waiting on dotfiles#3386). A lesson named outside `lesson-NNN-*.md` passes the check unseen: dotfiles#3415.

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
