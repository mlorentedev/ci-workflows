---
spec: "CI-004-toolchain-setup"
verdict: "PASS"
reviewed_sha: "8eeba76c36a604c2d1b57aad4cdc0e98dfed06f7"
reviewer: "agy/gemini-3.8-flash-high"
date: "2026-11-11"
---

## Adversarial review

**Scope**: CI-004-toolchain-setup
**Sources**: specs/CI-004-toolchain-setup/{proposal,tasks,verification,features.json}.md, git diff 7991c31384d479b20125675c034b52641fd9cc07...HEAD

### Spec and task alignment
- **Acceptance criteria coverage**: All 5 acceptance criteria from `proposal.md` (AC1 Shape tests, AC2 Version source, AC3 Cache proof, AC4 Gitea pilot, AC5 Per-platform keys) are covered by explicit tests and live run evidence in `verification.md`.
- **Task completion**: All tasks in `tasks.md` across PR 1 (`setup-node`), PR 2 (`setup-python-poetry`), PR 3 (`setup-python-uv`), PR 4 (`setup-go-lint`), and closing tasks are checked `[x]` with corresponding commits in git history.
- **Harness & contract validation**: `features.json` contains 17 machine-readable features; all 17 executable verification commands were re-run fresh and passed cleanly. Contract digests match `dotf spec digest CI-004-toolchain-setup` exactly.
- **Test suite status**: The complete test suite (`bats tests/`) passes 241/241 tests with 0 failures; `actionlint` is completely clean with 0 errors; all composite scripts pass `shellcheck` with zero warnings.
- **Promotions**: `docs/lessons/lesson-009-a-cache-hit-is-proved-by-rerunning-the-same-job.md` was created and verified.

### Findings

| Severity | Reality | Area | Finding | Evidence | Test (named, or UNTESTED) | Fix location (code / tests / spec / vault) |
|----------|---------|------|---------|----------|---------------------------|---------------------------------------------|
| Minor | THEORETICAL | setup-node/playwright | Playwright browser default cache directory on macOS runners is `~/Library/Caches/ms-playwright`, but the composite's cache path is hardcoded to `~/.cache/ms-playwright`. | `.github/actions/setup-node/action.yml` L87; Playwright documentation for macOS cache paths | `tests/setup-node.bats` -> `@test "the Playwright cache key holds the platform, the arch and the Playwright version"` | code |
| Minor | THEORETICAL | setup-python-uv | `read -r python <"${file}"` retains trailing carriage return `\r` if `.python-version` uses Windows CRLF line endings, publishing e.g. `python-version=3.13\r` to `${GITHUB_OUTPUT}`. | `.github/actions/setup-python-uv/action.yml` L54; reproduction in bash with `printf "3.13\r\n" \| read -r p` | UNTESTED | code |
| Minor | THEORETICAL | setup-node/resolve | `setup-node` does not pre-validate existence of `package-lock.json` in `resolve` when `playwright: false`, deferring missing lockfile failure to `actions/setup-node`'s generic error. | `.github/actions/setup-node/action.yml` L44-55 vs `.github/actions/setup-python-poetry/action.yml` L68 | UNTESTED | code |

### Evaluator rubric

| Dimension | Grade (A-D) | Rationale (one line) |
|-----------|-------------|----------------------|
| Correctness        | B | All 5 acceptance criteria verified with green tests and smoke proofs; minor theoretical cross-platform/CRLF edge cases noted. |
| Verification       | A | Exemplary reproducible verification with GitHub/Gitea run IDs, job citations, warm/hit pairs, and 17/17 passing feature checks. |
| Scope              | A | Strict alignment with proposal.md; 4 toolchain composites, fixtures, smoke jobs, docs, and lesson-009 with zero scope creep. |
| Reliability        | A | Robust input validation, graceful degradation without cache servers, and automatic venv recovery on broken interpreter links. |
| Maintainability    | A | All scripts ≤30 lines, cyclomatic complexity ≤6, clean actionlint/shellcheck, and third-party actions pinned by 40-hex SHA. |
| Handoff-readiness  | A | Lesson-009 captured, ADR and pattern dispositions recorded, README thoroughly documented with examples, and tickets up to date. |

### Verdict
PASS

### Recommended next steps
- `dotf spec archive CI-004-toolchain-setup` is **advisable** in the current state.
- For follow-up maintenance (can be dispositioned in `verification.md` or addressed in a future maintenance pass):
  1. Expand `setup-node`'s Playwright cache path to include `~/Library/Caches/ms-playwright` for macOS runner compatibility.
  2. Strip trailing `\r` from `python` in `setup-python-uv/action.yml` (`python="${python%$'\r'}"`) to guard against Windows CRLF `.python-version` files.
  3. Consider adding a pre-flight `[ -f "${WORKDIR}/package-lock.json" ]` check in `setup-node/action.yml` `resolve` for consistency with the other composites.
