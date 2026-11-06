---
id: "CI-002-release"
type: spec-review
created: "2026-11-05"
reviewed_sha: "97ef3f7a4daef2936a9dce02b73a1becee5d6a45"
reviewer: "independent reviewer agent (not the implementer)"
verdict: PASS-WITH-GAPS
---

# Adversarial review - CI-002-release

**Verdict: PASS-WITH-GAPS.** No Blocker, no Major. All six criteria hold against the code and the live
runs. Rubric: Correctness B, Verification B, Scope A, Reliability B, Maintainability A, Handoff B.

Ran: `bats tests/` (88 ok), `actionlint` (exit 0), every `features.json` command (exit 0, f6 over REST).
The pinned release-please-action SHA resolves to v5.0.0.

| # | Finding | Disposition |
|---|---|---|
| M1 | A hidden-type push cutting no release is not yet observed live after #25. | Recorded in `verification.md`; the merge of #26 is the first live case. |
| M2 | `verification.md` said 87 tests; there are 88. | Fixed. |
| M3 | f1 and f3 `evidence` counts were stale (13 and 5). | Fixed, `evidence` field only. |
| M4 | `tasks.md` still names `changelog-type: github`. | Declined: a historical setup note in the contract set; supersession noted in `verification.md`. |
| M5 | README said release notes come from merged pull requests. | Fixed. |
| M6 | No `closes` depends on repo squash defaults; merge commits and rebase still carry bodies. | Noted; tracked in dotfiles#3169 and dotfiles#3198. |
| M7 | Proposal says no `permissions`, `release.yml` sets a job-level `permissions: {}`. | No change: the test enforces exactly that, and `verification.md` records the decision. |
