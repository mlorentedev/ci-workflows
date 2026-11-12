---
spec: "CI-011-macos-smoke"
verdict: "PASS-WITH-GAPS"
reviewed_sha: "4bc2291403c7b5c97b88b89df3f075676b86bacc"
reviewer: "nan/mimo-v2.6-flash"
date: "2026-11-11"
---

## Adversarial review

**Scope**: CI-011-macos-smoke (issue mlorentedev/ci-workflows#71, PR #79, merged as `c99cf9a`)
**Sources**: `specs/CI-011-macos-smoke/{proposal.md,tasks.md,features.json,verification.md}`;
`git diff 4a9a88320c3f34da8df3803e30ac60b5d7256360...HEAD` (launcher-resolved base; HEAD `4bc2291`);
lint run [43065317189](https://github.com/mlorentedev/ci-workflows/actions/runs/43065317189) job logs via `gh`.

### Spec and task alignment

- **Range.** Three commits since base: `c99cf9a` (#79 — the spec's work, 8 files, all CI-011), plus
  `0b4742d` (#78, review.yml concurrency) and `4bc2291` (#83, CI-007 spec docs), which arrived in the
  range through the merge. The spec's own commit contains no unrelated changes (tasks.md "[x] No
  unrelated changes in the diff" holds for it). The two foreign commits do not interact with CI-011's
  acceptance criteria — observations below.
- **Contract integrity.** `dotf spec digest CI-011-macos-smoke` reproduces `review-request.json`'s
  `contract_digests` exactly (features.json / proposal.md / tasks.md). No `[AGENT-DRAFT]` or
  `[AGENT-SUGGESTION]` tags in the spec folder.
- **AC1** (each smoke on `macos-latest`; rerun reports `cache-hit == 'true'`):
  - Shape: `tests/toolchain-smokes.bats` "every toolchain smoke runs on macOS and Linux" —
    mutation-verified: pinning node to `ubuntu-latest` (M1) or `fail-fast: true` (M7) turns it red.
  - Rerun evidence reproduced live: run 43065317189 is on **attempt 3**, all four macOS jobs
    `success`, logs show `cache-hit=true` — node job 130680213696 (`node-cache-macOS-arm64-npm-6d2269b8…`),
    poetry 130680213806 (`poetry-cache-hit=true`), uv 130680213844, go 130680213821. Job ids in
    verification.md match the API. The uv `python-cache-hit=false` is the managed-Python cache,
    documented in verification.md and not claimed by AC1.
- **AC2** (`playwright: "true"`; browser path filled and restored on macOS):
  "the node smoke caches Playwright: playwright input, Chromium install, browsers path checked" —
  mutation-verified (M2: input removed → red); fixture pin "the node fixture pins @playwright/test
  exactly in its lockfile…" — mutation-verified (M6: lockfile version → red). Live log: attempt 3
  shows `playwright-cache-hit=true` and `/Users/runner/.cache/ms-playwright/chromium-1248`.
- **AC3** (no unconditional macOS job on `pull_request`; stays in `gate`'s needs):
  "every macOS leg is behind the toolchains area and stays in gate's needs" — mutation-verified
  (M3: `if: true` → red; M5: drop from `gate.needs` → red), plus "no workflow trigger runs the
  smokes outside pull requests and main". Bonus claim in the working-tree verification.md
  (`dotf lint fleet`) is **UNVERIFIED** — see finding 5.
- **Fresh verification run by this reviewer** (this session): `bats tests/` → 261/261, exit 0;
  `actionlint -shellcheck=shellcheck` → exit 0; all three `features.json` `bats --filter …`
  commands green; the node Report script executed under `/bin/bash` 3.2.57 → good key exit 0,
  key missing arch exit 1 (named `::error::`), empty key exit 1.
- **Process**: PR #79 MERGED with body referencing CI-011; issue #71 CLOSED; tasks.md boxes all
  match diff/CI evidence; verification.md carries reproducible job ids (reproduced above).

### Findings

| Severity | Reality | Area | Finding | Evidence | Test (named, or UNTESTED) | Fix location |
|----------|---------|------|---------|----------|---------------------------|--------------|
| Minor | REAL | tests | The node smoke's cache-key guard (the "Report the cache" `case`, rewritten in this diff from `${KEY,,}` to `lower()`) has **no named test**. A neutered guard (pattern → `*`) and a broken guard (never-matching pattern) both leave the suite exactly at baseline — controlled probe in a `mktemp -d` copy: baseline 26 environmental failures, identical failure lists under both mutations, zero toolchain-smokes failures — while the equivalent uv guard has `tests/setup-python-uv.bats` "the uv smoke fails a key without the platform and the arch". Fail-closed breakage is caught by runtime CI on the next toolchains PR; fail-open weakening is caught by nothing. Severity below the "no negative test = Major default" because the gap is pre-existing at base (`git show 4a9a883:tests/setup-node.bats` has no report test), the rewrite preserved behavior (hand-run both directions under /bin/bash 3.2.57, above), and runtime CI guards the breaking direction. | mutation probes M8/M9 vs `$TMP` baseline, this session | **UNTESTED** (uv's twin named above is the model) | tests — add an uv-style test extracting the node Report script: good key → 0, key missing arch → 1 |
| Minor | REAL | spec artifacts | Proposal Risks say "the node job's timeout rises to 10 minutes"; the diff raises **all four** smokes from 5 to 10 (poetry, uv, go undocumented). No AC affected; +5 min is justified by the macOS leg, just under-recorded. | diff: four × `timeout-minutes: 10` vs proposal.md Risks | n/a (doc drift, observed) | spec — contract set is closed under this verdict: disposition in `verification.md` or a follow-up ticket, **not** a proposal.md edit |
| Minor | THEORETICAL | spec artifacts | Proposal Risks claim "The composites are already tested under 3.2 by bats (lesson 010)". No test pins bash 3.2 (`grep '3.2' tests/` matches only the test this spec adds); bats executes scripts under PATH bash — CI runs ubuntu bash 5.x, this host resolves `bash` to Homebrew 5.3, and the four toolchain composites' scripts are shape-asserted (`setup-node.bats`, yq) and shellchecked (`composites-shellcheck.bats`, `-s bash`, which does not enforce 3.2), not executed. Lesson 010 itself concludes the opposite caution: a local shell test runs the local bash only. Mitigation: post-#79 the macOS legs run the composites for real (all four green, verified) so the conclusion holds regardless of the wording. | grep evidence above; `docs/lessons/lesson-010-…` closing line | n/a (rationale wording) | spec — disposition note in `verification.md`; no contract edit requested under this verdict |
| Minor | SPECULATIVE | tests | "the smokes' run steps avoid bash 4 case expansions…" passes **vacuously** if its yq selection errors or yields no input (`grep` exits 1 → `[ "$status" -ne 0 ]` → pass). Mitigated: a missing/renamed job fails test 1 through the same `job()` accessor, and the identical selection succeeds for node in the Playwright test — but for the poetry/uv/go run steps no other test consumes that exact selection. | code read of `tests/toolchain-smokes.bats:34-41` | UNTESTED (no test of the guard itself) | tests — assert the yq selection is non-empty before the grep; surface only, does not gate |
| Question | — | verification.md | The **working tree's** verification.md (uncommitted; `git status` shows ` M`, HEAD still reads "`dotf lint` has no checker …") adds an AC3 bonus claim: `dotf lint fleet`, built from dotfiles main `c94246c`, reports `[OK]`. Not reproducible in this run: installed dotf rejects the subcommand (`Error: unknown command "fleet" for "dotf lint"`; `dotf spec check` is also absent), and building dotfiles main is outside this review's scope. | `dotf lint fleet` output; `git diff specs/CI-011-macos-smoke/verification.md` | **UNVERIFIED** | verification.md (outside the staleness set) — make it runnable or restate as the proposal does (the bats `if:` test is AC3's evidence and is verified) |

**Out-of-spec, in-range observations** (reported, not gated — they do not interact with CI-011's ACs):

- #78 (`review.yml` concurrency key + `tests/review-concurrency.bats`) and #83 (CI-007 contract docs)
  arrived in the range; #78's five tests are green in the suite run above; the concurrency expression
  is runner-evaluated (not shell) and actionlint parses it cleanly.
- #83 edits CI-007's `features.json` f5 to name `bats tests/class-guard.bats` and a `pr-agent.yml`
  step ("Check the class paragraph against the registry") — **both absent at this sha** (future #82).
  `specs.bats` only requires a non-empty verification string, so the suite stays green. This is
  CI-007's contract and belongs to CI-007's own review; flagged here because the range holds it.

### Evaluator rubric

| Dimension | Grade (A-D) | Rationale (one line) |
|-----------|-------------|----------------------|
| Correctness | A | All three ACs verified against live CI logs and mutation-probed; negative paths of the rewritten guard exercised under /bin/bash 3.2.57 (0/1/1); no observed defect. |
| Verification | B | Run/job-id evidence reproduced live and contract digests match; but one bonus claim (`dotf lint fleet`) is UNVERIFIED and the rewritten node key guard carries no named test. |
| Scope | B | Spec's own commit (#79) matches the proposal exactly; range holds #78/#83 via merge, and the four-timeout change is under-documented in the proposal. |
| Reliability | A | `fail-fast: false`, timeouts raised, per-OS/arch cache keys, loud failures for bad/empty keys and missing Chromium path, `gate` still needs every smoke. |
| Maintainability | B | Clear structure, bash-3.2-safe rewrite (`tr`/`lower()`), comments explain why; test file concise, but the vacuous-pass guard and missing node report test sit below bar. |
| Handoff-readiness | A | proposal/tasks/features/verification all updated, promotion candidates explicitly dispositioned, PR merged referencing the spec, issue #71 closed. |

### Verdict

**PASS WITH GAPS** — no Blockers, no Majors; rubric all B or above (no C, no D); five Minor/Question
findings, each tracked above with a disposition line. The REAL minors (unguarded node key test,
timeout under-documentation) and the UNVERIFIED `dotf lint fleet` claim are dispositions for
`verification.md`/a follow-up ticket, not archive blockers; the SPECULATIVE finding is surfaced only.

### Recommended next steps

Contract set (`proposal.md`, `tasks.md`, `features.json`) is **closed** under this verdict — no
edits requested; the implementer disposes the following in `verification.md` (applied / ticketed /
declined with a reason), or carries them into a follow-up ticket:

1. Add the uv-style named test for the node Report script (finding 1) — tests, out of the
   contract set, safe to apply without invalidating this review.
2. Make the bash-4 scan test fail-closed on empty yq output (finding 4) — tests.
3. Make the `dotf lint fleet` AC3 claim reproducible or restate it (finding 5) — verification.md,
   which is excluded from the staleness check for exactly this purpose.
4. Record the four-timeout rationale and the composites-3.2 wording (findings 2–3) as disposition
   notes in `verification.md`; do not edit proposal.md while this verdict stands.
5. Route the CI-007 f5 future-reference to CI-007's own review round (out-of-scope observation).

**Completion**: (a) verdict — PASS WITH GAPS; (b) `dotf spec archive CI-011-macos-smoke` is
**advisable** — the verdict is passing, contract digests match, no draft tags; the gaps are tracked
dispositions, and items 1–4 can land outside the contract set without re-review; (c) not a FAIL, so
no minimum flip-set is required.
