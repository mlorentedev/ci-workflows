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

- Test suite: `bats tests/` reported 59 of 59 ok at merge, and 88 of 88 at `133d3c0`. `actionlint` reports no findings.
- The command of every entry in `features.json` exits 0.
- Manual smoke test: the consumers of issue #9 criterion 3, after merge.
  - **GitHub.** This repository's `lint.yml` runs `changes`, `lint`, `test` and `gate` at v0.3.0 (#22,
    merged as `df6cb19`). `gate` reported success on `main` at `df6cb19`.
  - **Gitea, act_runner v4.1.0.** `personal/imagesensortool` PR 151 (merged as `ccdcc47`) gates
    `image.yml`.
    - Docs-only PR 153 (`96c3f8e`): `image` skipped and `gate` passed. PR 152 matched.
    - Master run at `ccdcc47`: the full run, so `yq` was found; `image` built and pushed.
    - Run 3009 (PR 151) first failed on a runner docker timeout. `gate` failed with `changes`, and the
      rerun passed.
    - To re-check: <https://gitea.kubelab.live/personal/imagesensortool/pulls/151>, `/pulls/153`,
      `/actions/runs/3009`, and the commit statuses of `96c3f8e171069c2828d301256ed8d29d3c8e39f5`
      (`GET /api/v1/repos/personal/imagesensortool/commits/<sha>/statuses`).
  - The three Gitea questions in the proposal's Risks are answered yes: act_runner resolves the nested
    `uses:` from github.com, it runs `node24`, and the job token lists the pull request's files.
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

## Adversarial review

An independent review was run on 2026-11-05, at `3b6d1a6`. Its verdict was PASS-WITH-GAPS: no Blocker and no
Major against the product. It re-ran the suite (88 of 88 ok), actionlint and every `features.json`
command, and it mutated the actions on a scratch copy. There is no pool-signed `review.md`, because this
repository has no reviewer pool (#28).

| # | Finding | Disposition |
|---|---|---|
| 1 | Major (test gap). The full-run tests set `FULL_RUN_EVENTS` themselves, so dropping `schedule` from the default fails nothing. | Ticketed: #27 |
| 2 | Minor. The f1 filter did not select "a code pull request reports its area". | Fixed in `aaec0b1` |
| 3 | Minor. The f5 grep did not check the area map, the outputs or the protection procedure. | Fixed in `aaec0b1` |
| 4 | Minor. Removing `token:` from the filter step fails no test. | Ticketed: #27 |
| 5 | Minor. No GitHub docs-only pull request is cited for the skip path. | The pull request that archives this spec is docs-only; its run is cited on the pull request and on #9 |
| 6 | Minor. Issue #9 stays open after archive. | The archiving pull request closes #9 |

The Gitea claims were not re-checked by the reviewer, so this spec archives on them as owner-attested.
The links above make them re-checkable.

## Archive checklist

- [x] `proposal.md` frontmatter set to `status: archived`
- [x] Folder moved: `specs/CI-001-gate-and-changes/` -> `specs/archive/CI-001-gate-and-changes/`
- [ ] Bitácora board ticket for this spec moved to Done / closed with PR link (ADR-018): #9 closes with this pull request
- [x] Promotions above executed (if any)
