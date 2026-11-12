---
spec: "CI-006-pages"
verdict: "PASS"
reviewed_sha: "2391d6cce41a0fe79a8fcc09ad8dcb9de9461c5f"
reviewer: "nan/qwen3.8-flash"
date: "2026-11-12"
---

## Adversarial review

**Scope**: CI-006-pages / `git diff a249f67957c9110bdf07f48c1ec21bad186a0f33...HEAD`
**Sources**: `specs/CI-006-pages/{proposal,tasks,verification}.md`, `features.json`;
spec commits `0264c74a961a` (feat: workflow + tests + README) and `2391d6cce41a`
(docs: record first consumer deploy). The other 40 commits in the range arrived
through merges of unrelated work (pr-agent, docker-build, releases) and were read
only where they touch the same files — `tests/` and `README.md` carry their
additions independently; nothing in the pages change interacts with them.

Contract digests verified: `dotf spec digest CI-006-pages` output equals
`review-request.json`'s `contract_digests` for `proposal.md`, `tasks.md` and
`features.json` — this review is against the current contract.

### Spec and task alignment

- Every `[x]` in tasks.md and proposal.md was re-verified independently, not
  trusted:
  - `bats tests/pages-shape.bats` → 15/15 ok; `bats tests/pages-callers.bats` →
    5/5 ok; the features.json `--filter` claims reproduce exactly (8 and 8).
  - Full suite `bats tests/` → 317/317 ok, exit 0. `actionlint` (with
    shellcheck) → clean, exit 0.
  - AC5 (external claims all confirmed via `gh`): ts-bridge PR #741 `MERGED`,
    merge commit `9c9d70b4e088...`; run 43288112747 (`Deploy to GitHub Pages`)
    `completed/success` with `pages / build` (131426819277) and
    `pages / deploy` (131427043625) both success; the caller at that commit
    pins `pages.yml@2355330358344bb08c0b7a305be4ed6488f23d0c # v0.6.0`;
    `https://mlorentedev.github.io/ts-bridge/` returns 200. The tag v0.6.0
    resolves to `2355330…`, `0264c74` is an ancestor of it, and
    `.github/workflows/pages.yml` exists at that tree — the pin really carries
    this workflow.
  - All four action pins resolve to their tag comments on the remotes
    (`git ls-remote`: checkout v7.0.1, setup-node v7.1.0,
    upload-pages-artifact v5.0.0, deploy-pages v5.0.1 — all match).
  - Fixture-vs-reality claim checked: `tests/fixtures/pages-callers/ts-bridge.yml`
    `jobs:` block matches the merged ts-bridge file except the pin placeholder,
    as verification.md states (triggers differ — the fixture claim is scoped to
    `jobs:` and is accurate).
- No `[AGENT-DRAFT]` / `[AGENT-SUGGESTION]` tags in any spec file.
- AGENTS.md rules 1–4 hold: workflow_call-only, every input defaulted, no
  secrets at all, job ids `build`/`deploy`, narrow job-level permissions, no
  branch/trigger/workflow-permissions/concurrency, 40-hex pins with tag
  comments, `run:` blocks are single lines (no logic belongs in dotf here).

### Attempted refutations (what I tried to break, and what happened)

Eight mutations of `pages.yml` / fixtures were applied and reverted (tree
confirmed clean after each; final `git status` shows only spec-folder files):

| Mutation | Caught by |
|---|---|
| `build` permissions `contents: read` → `write` | test "build asks only to read contents" |
| drop `deploy` `timeout-minutes` | test "every job has a timeout" (file also breaks YAML-wide detection) |
| deploy `if` inverted to `== pull_request` | test "a pull request builds but neither uploads nor deploys" |
| upload-pages-artifact step loses its PR guard | same test |
| drop `persist-credentials: false` | test "checkout does not persist credentials" |
| `${{ inputs.build_command }}` interpolated into `run:` | test "inputs reach run blocks through env" (actionlint does NOT catch this — the bats test is the only guard, and it works) |
| add top-level `permissions:` | test "top-level permissions and concurrency stay with the caller" |
| rename `build` job → `site`; make `check_command` required, drop default | "the jobs are build and deploy" (×5 cascading); "every input has a default" |
| hive fixture loses `id-token: write` | callers test "the caller grants what each job asks for" |

The env-passing design (`BUILD_COMMAND` via `env:`, never interpolated) was
confirmed by mutation to be test-guarded, and the `secrets-contract.bats` gate
covers `pages.yml`'s zero-secret declaration. The permission-grant test derives
its expectation from the workflow's own `permissions` block, so a future widening
inside `pages.yml` breaks the caller fixtures — that coupling is a genuine
strength for AC2/AC3 persistence.

### Findings

| Severity | Reality | Area | Finding | Evidence | Test (named, or UNTESTED) | Fix location |
|---|---|---|---|---|---|---|
| Minor | SPECULATIVE | build step | A whitespace-only `check_command` (`" "`) passes the `!= ''` guard and runs `bash -c " "` — a no-op success, so a misconfigured check silently checks nothing | code read of `pages.yml` Check step; not reproduced as a consumer incident | UNTESTED (`check_is_optional` covers empty, not whitespace) | code or tests, if the owner wants it; decline is defensible — caller's own input, own repo |
| Minor | REAL | spec artifacts | `features.json` f5 still reads `state: "pending"`, `evidence: ""`, with a verification command ending `exit 1`, while HEAD ticked AC5 in proposal/tasks and recorded real evidence in verification.md | observed at HEAD: mechanical list contradicts prose record | nothing runs these commands (specs.bats only parses) — UNTESTED by construction | spec (features.json). Note: `state`/`evidence` are harness-owned fields normalized out of the contract digest, so updating them after this review does NOT stale it; changing f5's `verification` string WOULD. Repo convention tolerates this (archived CI-004/CI-011 shipped `pending` entries), so it is a bookkeeping nit, not a gate blocker |
| Minor | THEORETICAL | tests / pins | `pins_every_action` validates SHA form and comment form, not SHA↔tag agreement; a well-formed wrong tag comment (`# v8.0.0` on the v7.0.1 SHA) would pass CI | code read; mitigated — all four tags verified correct today by `git ls-remote` (this review and verification.md both re-ran it) | UNTESTED (no named test asserts tag truth; a network bats could) | tests, or accept as review-time check; a pin change is a PR the human reads anyway |
| Question | — | board | issue #32 is still OPEN while the spec is `verifying` — consistent today (active spec ↔ open issue), but at archive the owner must close #32, answer the three `<answer at archive>` promotion lines, and the `deploy`-vs-`build` check-context line in README stays caller-side truth | `gh issue view 32` → OPEN; verification.md's "Promotion candidates" are template placeholders | n/a | board/process at archive, not this diff |

No Blockers. No Majors. None of the Minors is a Major: none changes the
workflow's behavior on any path a real caller takes today, and each has a
disposition (decline, or a non-staling field, or an accepted review-time check).

### Evaluator rubric

| Dimension | Grade | Rationale |
|---|---|---|
| Correctness | A | All 5 ACs independently re-verified (local suite, actionlint, 8 mutations, gh-confirmed external evidence, ls-confirmed pins); no observed defect |
| Verification | A | Every claim in verification.md/features.json reproduced 1:1 this round, including the external ts-bridge run ids and the 8+8 filter counts |
| Scope | A | The two spec commits touch exactly the 12 files the proposal declares; no creep; range extras are merged-in unrelated work |
| Reliability | B | PR guards, timeouts, credential-drop, env-passed commands all test-held; whitespace-check edge is the one unhandled input path |
| Maintainability | A | 86-line workflow, single-line `run:` blocks, rules as named bash functions with bad-fixtures; CC trivial throughout |
| Handoff-readiness | B | Spec + tasks + verification updated in-branch with named commits; f5 mechanical state stale and promotion lines awaiting the archive answer |

### Verdict

**PASS**

Per the aggregation rule: no D, no C, no Blocker, no Major (any reality).
Adversarial posture held — the change survived every mutation aimed at its
documented guarantees.

`dotf spec archive CI-006-pages` is **advisable in mechanics** after the owner:
(1) answers the three "Promotion candidates" lines in verification.md
(`yes: <path>` or `no: <reason>` — the archive's third pre-flight requires it),
and (2) closes issue #32 alongside the archive. The Minor findings may be
dispositioned in verification.md afterwards; touching f5's `state`/`evidence`
in features.json will not stale this review, touching its `verification` string
will.

### Recommended next steps

For the implementer/owner (none of these reopens the verdict; none requires a
contract edit that would stale this review):

1. features.json f5: set `state: "passing"`, `evidence` to the ts-bridge run
   already recorded in verification.md — harness-owned fields, digest-safe
   (tracked finding #2; or disposition it as "convention, decline").
2. Disposition the whitespace `check_command` finding (track or decline with a
   line in verification.md).
3. Decide the SHA↔tag-truth check: accept the review-time `git ls-remote`
   (current practice, recorded) or ask for a network bats case; file a ticket
   if the latter (finding #3).
4. At archive: answer the three promotion-candidate lines, close #32.
5. Migration of the remaining four consumers stays out of scope per proposal —
   each in its own PR against a pinned release, as CI-006 declared.
