---
spec: "CI-007-fleet-pr-agent"
verdict: "PASS-WITH-GAPS"
reviewed_sha: "5a26b30df69ad2ed34db410ff2b96dc2312dd350"
reviewer: "nan/deepseek-v4-flash"
date: "2026-11-15"
---

## Adversarial review

**Scope**: CI-007-fleet-pr-agent — diff `e64d2c6a95a7165e021825ebf6da716958192da5...HEAD` (whole change; the spec's 12 commits plus the work that merged through it, judged only where it interacts)
**Sources**: `specs/CI-007-fleet-pr-agent/{proposal,tasks,verification}.md`, `features.json`, `review-request.json`; `pr-agent/{pr-agent.yml,class-paragraph.txt,classification.json}`; `.github/workflows/pr-agent.yml`; `tests/{class-guard,review-concurrency,specs,callers,pr-agent-shape,hygiene}.bats`; `docs/lessons/lesson-016,018,019,020`; live GitHub state of the twelve adopters.

### Spec and task alignment

The contract digests in `review-request.json` match `dotf spec digest CI-007-fleet-pr-agent` — no contract drift.

All four acceptance criteria were re-verified live in this session, not read from `verification.md`:

| Criterion | Command run | Result |
|---|---|---|
| AC1 pinned by full SHA | `features.json` f1 | exit 0 |
| AC2 no copy of the review steps | f2 | exit 0 |
| AC3 paragraph + registry (+ guard) | f3, f5 | exit 0 (f5: 13/13 bats cases) |
| AC4 every adopter PR reviewed, no batch lost | f4 | exit 0 |

Beyond the features, I checked the claims that only `verification.md` asserted:

- Every adopter's caller pins `pr-agent.yml@9b34f5b2815a3090d77d7589ef8bcc5087045544` (v0.8.0) and its `concurrency.group` is byte-identical to `pr-agent/pr-agent.yml`'s: 12/12, matching `verification.md`'s rollout paragraph.
- The class paragraph is a byte-identical prefix of `pr_reviewer.extra_instructions` in all twelve adopters (parsed with `tomllib`), so the "byte-identical, rendered from one template" clause is true in fact even though nothing enforces it (finding 1).
- hive holds one `pr-agent.yml` and no `pr-agent-shared.yml`; every adopter has exactly one `pr-agent.yml`, so the task's "delete both old files" landed.
- leaving-denver's `pr-agent` workflow is `active`, as `verification.md` records after the manual-disable incident.
- The guard shipped: `git show 9b34f5b:.github/workflows/pr-agent.yml` carries the `class_guard` step, and the only delta between it and HEAD is the `pr-agent/class-paragraph.txt` path in the error message (#127).
- The archive-move hazard from the first review is closed: `tests/specs.bats` (5/5) scans `.github`, `tests`, `harness`, `renovate`, `pr-agent`, `README.md` and finds no path into an active spec folder; the only stragglers are the `specs/**/features.json` trigger glob in `lint.yml` and `specs.bats`' own fixture string. Lesson 020 records it.
- `actionlint` on both `pr-agent.yml` files (shared and kit) exits 0; the spec's test surface is green: `review-concurrency` 12, `pr-agent-shape` 18, `callers` 11, `hygiene` 18, `specs` 5, `class-guard` 13 — 77 cases, 0 failures.
- The whole suite reproduces `verification.md`'s "no regressions" claim on this commit: `bats tests/*.bats` → exit 0, 349 cases ok, 0 failures, 0 skips (the docker-build, docker-publish, toolchain-smoke and composite-shellcheck files included).
- Mutation probes (reverted): replacing the guard's `exit 1` in the missing-class branch with `true` turns `class-guard.bats` cases 6–9 red, so the suite is load-bearing for the guard's failure paths.

### Findings

| Severity | Reality | Area | Finding | Evidence | Test (named, or UNTESTED) | Fix location (code / tests / spec / vault) |
|----------|---------|------|---------|----------|---------------------------|---------------------------------------------|
| Major | THEORETICAL | guard fidelity | The class guard matches a class as a case-sensitive **substring** of `extra_instructions` (`grep -qF "${prefix}${class}"`), not as the spelling the triage reads. A paragraph that writes the token as a superset — `` `Class: REAL` ``, `Class: REAL,`, `Class: SPECULATIVE-ish` — passes the guard while `dotf pr triage-queue` reads *a whole line equal to prefix + class* (`harness/review-attestation.json` → `why`), so every finding arrives unclassified with no error: exactly the failure the step exists to prevent. `verification.md` says the fleet's own history already contains the backticked shape (svqtriana.github.io's old paragraph). | Reproduced: mutated `pr-agent/class-paragraph.txt` `"Class: SPECULATIVE"` → `"Class: SPECULATIVE-ish"`; `bats tests/class-guard.bats` stayed green 13/13. Guard script: `.github/workflows/pr-agent.yml` `class_guard` step. No adopter has drifted today (12/12 byte-identical, checked live), hence THEORETICAL for its occurrence. | UNTESTED for the drift direction: `@test "the kit's paragraph agrees with this repository's registry"` exists and passes **under the mutation**, so it does not hold the property it names. | code + tests — already scoped by #128 ("match the kit paragraph as a unit"); no contract edit. |
| Minor | REAL | concurrency key | The kit's key shares the review group only for `/cmd` followed by space, tab, LF or CR; it has no end-of-body case and no case folding, while the shared step classifies a bare `/review` as a review (`@test "the step runs a review for every spelling PR-Agent accepts"`, line 90) and `/Review` too (line 95). So the canonical re-run — `/review` with no argument — gets a group of its own: it does not supersede an in-flight review, and with the job's `queue: max` both runs execute, spending a second NaN call against the ≤5-slot budget the proposal names as the fleet's binding constraint. The kit's comment claims "or the end of the body", which the expression does not implement and `@test "a word that only begins with /review, such as /reviewed, gets its own group"` (line 81) actively forbids. | `pr-agent/pr-agent.yml` lines 25–48 (only `'/cmd '` and `format('/cmd{0}', sep)` literals, no `==`); `/review` = review at `tests/review-concurrency.bats` line 90, `/Review` at line 95. | UNTESTED: `@test "the key shares the group for exactly PR-Agent's review commands"` compares the command *sets* only and never evaluates the key expression against a comment body. | code + tests (`pr-agent/pr-agent.yml`, `tests/review-concurrency.bats`). |
| Minor | REAL | spec paths | `proposal.md` and `tasks.md` still point at `kit/pr-agent.yml`, `kit/class-paragraph.txt`, `kit/classification.json`; #127 moved them to `pr-agent/`. The archived contract therefore keeps a dead path, though `verification.md` records the translation ("Where this record and tasks.md say `kit/`, the files are now in `pr-agent/`"). | `ls pr-agent/` vs the `kit/` references in the contract files; `tests/specs.bats` cannot catch it because it scans code, not contract prose. | `@test "no workflow or test reads a file inside an active spec folder"` (does not apply; no test can bind contract prose) — UNTESTED. | spec artifacts, **closed under this verdict**: carry as a follow-up note, do not edit before archive. |
| Question | — | feature 1 scope | f1 accepts *any* 40-hex pin, so criterion 1 does not bind the fleet to the reviewed release. The tighter claim — all twelve on v0.8.0 — lives only in `verification.md`'s prose check, which I reproduced at 12/12. Confirm that is the intended split rather than widening f1 later. | `features.json` f1 regex `[0-9a-f]{40}`; manual 12/12 run on 2026-11-15. | `@test "..."` none in this repo; f1 is the check | spec (follow-up, not now). |

Debt noted and dispositioned elsewhere, not re-raised: #128 (guard matches the kit paragraph as a unit, covering finding 1 and the prose `Class:` false positive), #103 (rolling the #96 key to callers), #82/#113 (shipped in v0.8.0).

### Evaluator rubric

| Dimension | Grade (A-D) | Rationale (one line) |
|-----------|-------------|----------------------|
| Correctness        | B | All four criteria verified live and the fleet is in the intended state; the guard's byte-identity clause is unenforced (finding 1) and the concurrency key under-matches (finding 2). |
| Verification       | A | Every claim I re-ran reproduced exactly — f1–f5 exit 0, 12/12 SHA+group parity, byte-identical paragraphs, `leaving-denver` active — the rare case of evidence that survives independent replay. |
| Scope              | A | The CI-007 slice is the kit, the guard step, their tests and lessons; the kit's move out of the spec folder is deliberate and documented (lesson 020), and no adopter work leaked into this repository. |
| Reliability        | B | The guard handles 404 vs other fetch failures, and a failed guard stops the review without blaming the model (tested); the caller's key drifts from the shared classifier on bare and upper-case commands. |
| Maintainability    | B | Small, commented steps, table-driven fixtures; two comments claim parity the code and a sibling test contradict (findings 1–2), which is how the drift survived review. |
| Handoff-readiness  | A | Proposal, tasks, verification, `features.json` and four lessons are current; deviations and open items are named with tickets; promotion candidates are answered. |

### Verdict

**PASS WITH GAPS** — one open Major is THEORETICAL (finding 1, tracked as #128; the mechanism is reproduced but the fleet has not drifted), the rest are Minor or a question, and no rubric dimension is below B.

### Recommended next steps

All in the **non-contract set**; `proposal.md`, `tasks.md` and `features.json` are closed by this verdict and must not be edited before archive.

1. Close #128 by matching `pr-agent/class-paragraph.txt` as a unit (or by comparing on a whole line) in the `class_guard` step, and add a `tests/fixtures/class-guard` case whose paragraph is present-but-spelled-wrong — the mutation in finding 1 becomes the regression test. Until then, record in `verification.md` that the guard enforces presence, not identity.
2. Ticket the concurrency-key parity drift (finding 2): either add the end-of-body and case-folded forms to the key, or amend the kit's comment to say the key under-matches and why that is safe (`queue: max` serialises instead of cancelling), and add a test that evaluates the key expression against bodies — the `classify` helper already exists to model the shared side.
3. Leave `kit/` → `pr-agent/` as recorded: `verification.md` already carries the translation; no contract edit.
4. Answer the f1 question in `verification.md` (any 40-hex vs the v0.8.0 pin) so the tighter claim has a named home.

**Not reached (UNVERIFIED)**: the archive gate's own implementation beyond `dotf spec archive --help` and the three pre-flights it documents (the gate lives outside this repository, so the post-review `dotf spec archive` run itself is the first place its decision is observed). No adopter's own CI runs were re-executed here; the fleet state was read from the GitHub API instead. The archive's promotion-candidate pre-flight should pass as written: the lesson line answers `yes: docs/lessons/lesson-016-...`, which exists, and the other two answer `no: <reason>`.
