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
- [x] AC3: every macOS leg carries the `toolchains` condition and its job is in `gate`'s needs. Test: "every macOS leg is behind the toolchains area and stays in gate's needs". `dotf lint fleet`, built from dotfiles main at `c94246c` (the installed release lacks it), reports `[OK] no fleet lint findings`, exit 0, on ci-workflows main after #79 merged (`c99cf9a`): `fleet/os-on-pull-request` accepts a job with an `if:`.

## Test status

- `bats tests/`: 252 tests, 0 failures.
- `actionlint`: clean.
- The node Report step was run by hand under `/bin/bash` 3.2.57. A good key exits 0; a key without the arch exits 1.

## Decisions made during implementation

- `@playwright/test` is pinned to 1.64.1, not 1.65.0, which was six days old.
- The whole run was rerun for the hit evidence: GitHub refuses a second job rerun while the first is in progress (HTTP 403).
- `python-cache-hit=false` on the uv macOS leg is the managed-Python cache, which AC1 does not claim. The `cache-hit` output, uv's own cache, hits.

## Review dispositions

Verdict `PASS-WITH-GAPS` (`review.md`). The PR author did these dispositions.

- **Minor, node key guard untested:** applied. `tests/toolchain-smokes.bats` runs the node Report step for a good key and a key without the arch, under `bash` and `/bin/bash`. Neutering the guard to `*)` in a copy fails "the node smoke fails a key without the platform and the arch".
- **Minor, timeout drift:** recorded here. All four smokes went from 5 to 10 minutes, not only node; the macOS leg is the reason for each.
- **Minor, "composites tested under 3.2 by bats" overstated:** recorded here. bats runs the composites under the PATH bash (5.x in CI). What holds them to macOS is the four macOS legs, which run every composite for real since #79.
- **Speculative, vacuous pass of the bash 4 expansion test:** applied. The test now asserts each smoke's run steps are non-empty before the grep.
- **Question, `dotf lint fleet` not reproducible:** the reproduction is `git clone --depth 1 https://github.com/mlorentedev/dotfiles && (cd dotfiles/cli && go build -o ../../dotf-main ./cmd/dotf)`, then `./dotf-main lint fleet` in a ci-workflows checkout. The installed dotf predates the subcommand. AC3 rests on the bats test either way.

## Promotion candidates

- [x] Lesson for the repo's `docs/lessons/`? no: macOS's bash 3.2 is lesson 010's subject, and the test now enforces it
- [x] ADR-worthy decision for the repo's `docs/adr/adr-XXX.md`? no: a matrix over existing jobs, within ADR-001
- [x] New pattern candidate for `00_meta/patterns/`? no: one repository

## Archive checklist

- [x] `proposal.md` frontmatter set to `status: archived`
- [x] Folder moved: `specs/CI-011-macos-smoke/` -> `specs/archive/CI-011-macos-smoke/`
- [ ] Bitácora board ticket for this spec moved to Done / closed with PR link (ADR-018)
- [x] Promotions above executed (if any)
