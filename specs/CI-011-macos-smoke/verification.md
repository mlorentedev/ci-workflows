---
tags: [spec, verification]
created: "2026-11-11"
id: "CI-011-macos-smoke"
type: spec-verification
status: active
owner: manu
---

# Verification - CI-011-macos-smoke

## Evidence

- [x] AC1: every toolchain smoke runs on `macos-latest` and a rerun reports a hit. Commit `19ba233`, lint run 43065317189. Attempt 1 saved the caches; attempt 3 (the whole run rerun) restored them:
  - `smoke-setup-node (macos-latest)`, job 130680213696: `cache-hit=true`, key `node-cache-macOS-arm64-npm-6d2269b8…`
  - `smoke-setup-python-poetry (macos-latest)`, job 130680213806: `cache-hit=true`, `poetry-cache-hit=true`
  - `smoke-setup-python-uv (macos-latest)`, job 130680213844: `cache-hit=true`, key `setup-uv-2-aarch64-apple-darwin-…`
  - `smoke-setup-go-lint (macos-latest)`, job 130680213821: `cache-hit=true`
  - Test: `tests/toolchain-smokes.bats` "every toolchain smoke runs on macOS and Linux"
- [x] AC2: the node smoke on macOS installed Chromium into `/Users/runner/.cache/ms-playwright/chromium-1248`, and the rerun (job 130679639094, then 130680213696) reports `playwright-cache-hit=true`. Tests: "the node smoke caches Playwright…" and "the node fixture pins @playwright/test…"
- [x] AC3: every macOS leg carries the `toolchains` condition and its job is in `gate`'s needs. Test: "every macOS leg is behind the toolchains area and stays in gate's needs". `dotf lint` has no checker for the dotfiles#3147 rule yet.

## Test status

- `bats tests/`: 252 tests, 0 failures.
- `actionlint`: clean.
- The node Report step was run by hand under `/bin/bash` 3.2.57. A good key exits 0; a key without the arch exits 1.

## Decisions made during implementation

- `@playwright/test` is pinned to 1.64.1, not 1.65.0, which was six days old.
- The whole run was rerun for the hit evidence: GitHub refuses a second job rerun while the first is in progress (HTTP 403).
- `python-cache-hit=false` on the uv macOS leg is the managed-Python cache, which AC1 does not claim. The `cache-hit` output, uv's own cache, hits.

## Promotion candidates

- [x] Lesson for the repo's `docs/lessons/`? no: macOS's bash 3.2 is lesson 010's subject, and the test now enforces it
- [x] ADR-worthy decision for the repo's `docs/adr/adr-XXX.md`? no: a matrix over existing jobs, within ADR-001
- [x] New pattern candidate for `00_meta/patterns/`? no: one repository

## Archive checklist

- [ ] `proposal.md` frontmatter set to `status: archived`
- [ ] Folder moved: `specs/CI-011-macos-smoke/` -> `specs/archive/CI-011-macos-smoke/`
- [ ] Bitácora board ticket for this spec moved to Done / closed with PR link (ADR-018)
- [ ] Promotions above executed (if any)
