---
tags: [spec, verification, templates]
created: "2026-11-05"
id: "CI-004-toolchain-setup"
type: spec-verification
status: active
owner: manu
---

# Verification - CI-004-toolchain-setup

## Evidence

PR 1 (`setup-node`). Commits on `feat/issue-10-setup-node`.

- [x] AC1 shape: `tests/setup-node.bats` (inputs, outputs, bash, pins, setup-node wiring) at `9daf0c7`. Pins checked against the tags over the API: `actions/setup-node` v7.1.0 = `949feb2`, `actions/cache` v6.1.0 = `55cc834`.
- [x] AC2 version source: `tests/setup-node.bats` (version input, version file, neither fails naming both; Playwright version from the lockfile, failing without it) at `9daf0c7`.
- [ ] AC3 cache proof: `smoke-setup-node` and its wiring (the smoke tests in `tests/setup-node.bats`) at `1a9e15d`. The warm run on `main` and the hit on the next pull request are recorded after merge.
- [ ] AC4 Gitea: after merge, the imagesensortool pilot.
- [x] AC5 per-platform keys: the Playwright key test in `tests/setup-node.bats`; the smoke job fails when `cache-primary-key` does not start with `node-cache-<os>-<arch>-npm-` (`actions/setup-node` v7.1.0 builds it from `RUNNER_OS` and `os.arch()`, `src/cache-restore.ts`).

## Test status

- Test suite: `bats tests/` -> every test ok; `actionlint` clean.
- Manual smoke test: none locally; the smoke job is the run on the pull request.
- No regressions in existing test suite: yes.

## Decisions made during implementation

- `tests/setup-node.bats` also asserts that `gate` needs every other job of `lint.yml`. Nothing checked it, and a job outside gate's needs fails without blocking a merge (dotfiles lesson 356).
- The fixture lives under `tests/fixtures/`, which Renovate's `config:recommended` ignores, so its `is-number` pin raises no update pull requests.

## Promotion candidates

Answer each line `yes: <path>`, naming the file you promoted, or `no: <reason>`. `dotf spec archive` refuses a line left unanswered, a `no` without a reason, and a `yes` whose file does not exist; a `00_meta/` path is looked up in the vault.

- [ ] Lesson for the repo's `docs/lessons/`? <yes: path / no: reason>
- [ ] ADR-worthy decision for the repo's `docs/adr/adr-XXX.md`? <yes: path / no: reason>
- [ ] New pattern candidate for `00_meta/patterns/`? Only if this recurs in >1 project. <yes: path / no: reason>

## Archive checklist

- [ ] `proposal.md` frontmatter set to `status: archived`
- [ ] Folder moved: `specs/CI-004-toolchain-setup/` -> `specs/archive/CI-004-toolchain-setup/`
- [ ] Bitácora board ticket for this spec moved to Done / closed with PR link (ADR-018)
- [ ] Promotions above executed (if any)
