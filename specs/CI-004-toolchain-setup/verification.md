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
- [ ] AC3 cache proof: `smoke-setup-node` and its wiring (the smoke tests in `tests/setup-node.bats`), merged in #42. Warm: the push of `a249f67` to `main`, [run 42251446049](https://github.com/mlorentedev/ci-workflows/actions/runs/42251446049), logged `cache-hit=false`. Hit: the next push, `0264c74`, [run 42251942005](https://github.com/mlorentedev/ci-workflows/actions/runs/42251942005), logged `cache-hit=true` under the same `cache-primary-key=node-cache-Linux-x64-npm-806b948b7139806c95e68d1853f9f49393c1efade825a5e7b7fa544e30200faa`. The pushes of `d8ca1d6` and `d601782` hit too. Still pending: a hit on a pull request. A push to `main` restores from `main`'s own scope, while a pull request reads it as the base branch, which is the path callers use. The next CI-004 pull request touches `.github/actions/setup-*`, so its `smoke-setup-node` run records it.
- [x] AC4 Gitea: personal/imagesensortool#159 runs `setup-node` at v0.4.0 (`d601782`) on act_runner. Its first run, [run 3113 job 8103](https://gitea.kubelab.live/personal/imagesensortool/actions/runs/3113/jobs/8103), logged `cache-hit=true` with `cache-primary-key=node-cache-Linux-x64-npm-afd62013…`, and the job passed. The hit is the store that `master` had saved with `actions/setup-node` v6.4.0: the composite keeps that action's key format, so a repository adopting it keeps its warm cache. The cache server on the Gitea runner works, so no kubelab ticket is needed.
- [x] AC5 per-platform keys: the Playwright key test in `tests/setup-node.bats`; the smoke job fails when `cache-primary-key` does not start with `node-cache-<os>-<arch>-npm-` (`actions/setup-node` v7.1.0 builds it from `RUNNER_OS` and `os.arch()`, `src/cache-restore.ts`).

PR 2 (`setup-python-poetry`). Commits on `feat/issue-10-setup-python-poetry`.

- [x] AC1 setup-python-poetry shape: `tests/setup-python-poetry.bats` (inputs, outputs, bash, pins, the setup-python, cache and install wiring). Pins checked against the tags over the API: `actions/setup-python` v7.1.0 = `6d4fd22`, `actions/cache` v6.1.0 = `55cc834`.
- [x] AC2 setup-python-poetry version source: `tests/setup-python-poetry.bats` (version input, version file, neither fails naming both; an empty or inexact `poetry-version` fails; a missing `poetry.lock` fails naming it; Poetry is installed only when its cached venv lacks it).
- [ ] AC3 setup-python-poetry cache proof: `smoke-setup-python-poetry`. Pending its runs.
- [x] AC5 setup-python-poetry per-platform keys: the `keys` tests in `tests/setup-python-poetry.bats`. Both keys hold `runner.os`, `runner.arch` and the exact Python version, and an empty part fails the step.

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
