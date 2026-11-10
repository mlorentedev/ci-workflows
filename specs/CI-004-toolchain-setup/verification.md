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
- [x] AC3 cache proof: `smoke-setup-node` and its wiring (the smoke tests in `tests/setup-node.bats`), merged in #42. Warm: the push of `a249f67` to `main`, [run 42251446049](https://github.com/mlorentedev/ci-workflows/actions/runs/42251446049), logged `cache-hit=false`. Hit: the next push, `0264c74`, [run 42251942005](https://github.com/mlorentedev/ci-workflows/actions/runs/42251942005), logged `cache-hit=true` under the same `cache-primary-key=node-cache-Linux-x64-npm-806b948b7139806c95e68d1853f9f49393c1efade825a5e7b7fa544e30200faa`. The pushes of `d8ca1d6` and `d601782` hit too. On a pull request: #55, which touches `.github/actions/setup-*`, ran `smoke-setup-node` in [run 42764564823 job 129657938156](https://github.com/mlorentedev/ci-workflows/actions/runs/42764564823/job/129657938156). It logged `cache-hit=true` and restored `node-cache-Linux-x64-npm-806b948…`, the key that the pushes to `main` saved. A pull request reads `main`'s cache as its base branch, which is the path callers use.
- [x] AC4 Gitea: personal/imagesensortool#159 runs `setup-node` at v0.4.0 (`d601782`) on act_runner. Its first run, [run 3113 job 8103](https://gitea.kubelab.live/personal/imagesensortool/actions/runs/3113/jobs/8103), logged `cache-hit=true` with `cache-primary-key=node-cache-Linux-x64-npm-afd62013…`, and the job passed. The hit is the store that `master` had saved with `actions/setup-node` v6.4.0: the composite keeps that action's key format, so a repository adopting it keeps its warm cache. The cache server on the Gitea runner works, so no kubelab ticket is needed.
- [x] AC5 per-platform keys: the Playwright key test in `tests/setup-node.bats`; the smoke job fails when `cache-primary-key` does not start with `node-cache-<os>-<arch>-npm-` (`actions/setup-node` v7.1.0 builds it from `RUNNER_OS` and `os.arch()`, `src/cache-restore.ts`).

PR 2 (`setup-python-poetry`). Commits on `feat/issue-10-setup-python-poetry`.

- [x] AC1 setup-python-poetry shape: `tests/setup-python-poetry.bats` (inputs, outputs, bash, pins, the setup-python, cache and install wiring). Pins checked against the tags over the API: `actions/setup-python` v7.1.0 = `6d4fd22`, `actions/cache` v6.1.0 = `55cc834`.
- [x] AC2 setup-python-poetry version source: `tests/setup-python-poetry.bats` (version input, version file, neither fails naming both; an empty or inexact `poetry-version` fails; a missing `poetry.lock` fails naming it; Poetry is installed only when its cached venv lacks it).
- [x] AC3 setup-python-poetry cache proof: `smoke-setup-python-poetry` on #55, [run 42764564823](https://github.com/mlorentedev/ci-workflows/actions/runs/42764564823). Its second run logged `cache-hit=true`.
  - Warm: [job 129657938211](https://github.com/mlorentedev/ci-workflows/actions/runs/42764564823/job/129657938211) found no cache for `poetry-Linux-X64-py3.13.18-2.5.1` or `poetry-venv-Linux-X64-py3.13.18-7ef78774…`, installed Poetry 2.5.1 and the fixture, and saved both. `cache-hit` was empty, not `false`: `actions/cache` sets it only on a restore.
  - Hit: the rerun of that job, [job 129658540477](https://github.com/mlorentedev/ci-workflows/actions/runs/42764564823/job/129658540477), restored both keys. It logged `cache-hit=true` and `poetry-cache-hit=true`, skipped the Poetry install, and `poetry install` reported "No dependencies to install or update".
  - The scope is the pull request's own branch, both runs being on #55. A pull request reading `main`'s Poetry cache comes after this merges, from the next CI-004 pull request.
- [x] AC5 setup-python-poetry per-platform keys: the `keys` tests in `tests/setup-python-poetry.bats`. Both keys hold `runner.os`, `runner.arch` and the exact Python version, and an empty part fails the step.

PR 3 (`setup-python-uv`). Commits on `feat/issue-10-setup-python-uv`.

- [x] AC1 setup-python-uv shape: `tests/setup-python-uv.bats` (inputs, outputs, bash, pin, the setup-uv wiring). Pin checked against the tag over the API: `astral-sh/setup-uv` v10.3.3 = `68559e9`.
- [x] AC2 setup-python-uv version source: `tests/setup-python-uv.bats` (version input, first line of the version file, neither or an empty file fails naming both; a missing `uv.lock` fails naming it).
- [ ] AC3 setup-python-uv cache proof: `smoke-setup-python-uv`. Pending its runs.
- [x] AC5 setup-python-uv per-platform keys: the smoke job fails when `cache-primary-key` does not start with `setup-uv-2-<arch>-<platform>-` (`astral-sh/setup-uv` v10.3.3 builds it from `process.arch` and `process.platform`, `src/cache/restore-cache.ts`).

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
