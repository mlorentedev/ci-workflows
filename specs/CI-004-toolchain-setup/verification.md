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
- [x] AC3 setup-python-uv cache proof: `smoke-setup-python-uv` on #58, [run 42767427099](https://github.com/mlorentedev/ci-workflows/actions/runs/42767427099). Its second run logged `cache-hit=true`.
  - Warm: [job 129667140775](https://github.com/mlorentedev/ci-workflows/actions/runs/42767427099/job/129667140775) logged `cache-hit=false` and `python-cache-hit=false`, downloaded CPython 3.13.18, and saved under `setup-uv-2-x86_64-unknown-linux-gnu-ubuntu-24.04-3.13-py-97d49e0f…`.
  - Hit: the rerun of that job, [job 129667859606](https://github.com/mlorentedev/ci-workflows/actions/runs/42767427099/job/129667859606), restored both caches and logged `cache-hit=true` and `python-cache-hit=true`.
  - The scope is the pull request's own branch. A pull request reading `main`'s uv cache comes after this merges.
- [x] AC3 setup-python-poetry, read from `main`: the push of #55 to `main` saved both Poetry keys ([job 129664538608](https://github.com/mlorentedev/ci-workflows/actions/runs/42766617019/job/129664538608)). On #58, `smoke-setup-python-poetry` ([job 129667140896](https://github.com/mlorentedev/ci-workflows/actions/runs/42767427099/job/129667140896)) restored them as its base branch's. It logged `cache-hit=true` and `poetry-cache-hit=true`, and `poetry install` had nothing to do.
- [x] AC5 setup-python-uv per-platform keys: the smoke job fails when `cache-primary-key` does not start with `setup-uv-2-<arch>-<platform>-` (`astral-sh/setup-uv` v10.3.3 builds it in `src/cache/restore-cache.ts` from `process.arch` and `process.platform`, renamed in `src/utils/platforms.ts`). `tests/setup-python-uv.bats` runs that check against keys that do and do not name them.

PR 4 (`setup-go-lint`). Commits on `feat/issue-10-setup-go-lint`.

- [x] AC1 setup-go-lint shape: `tests/setup-go-lint.bats` (inputs, outputs, bash, both pins, the step order, the setup-go and lint wiring). Pins checked against the tags over the API: `actions/setup-go` v7.0.0 = `b7ad1da`, `golangci/golangci-lint-action` v9.3.0 = `ba0d7d2`.
- [x] AC2 setup-go-lint version sources: `tests/setup-go-lint.bats` (the Go version input or the version file, neither fails naming both; the golangci-lint input with or without its `v`, go.mod's golangci-lint/v2 line, neither fails naming both; a missing `go.sum` fails naming it).
- [x] AC3 setup-go-lint cache proof: `smoke-setup-go-lint` on #64, [run 42948162863](https://github.com/mlorentedev/ci-workflows/actions/runs/42948162863). Its second run logged `cache-hit=true`.
  - Warm: [job 130288140297](https://github.com/mlorentedev/ci-workflows/actions/runs/42948162863/job/130288140297) logged `cache-hit=false`, installed Go 1.25.14 from `go.mod`'s `go 1.25`, built and linted the fixture (`0 issues.`), and saved `setup-go-Linux-x64-ubuntu24-go-1.25.14-a363ac2e…`.
  - Hit: the rerun of that job, [job 130294223833](https://github.com/mlorentedev/ci-workflows/actions/runs/42948162863/job/130294223833), restored that key, logged `cache-hit=true`, and skipped the save ("Cache hit occurred on the primary key").
  - The lint action logged "Skipping cache restoration" and "Skipping cache saving" in both runs: only the binary was installed.
  - The scope is the pull request's own branch. A pull request reading `main`'s Go cache comes after this merges.
- [x] AC3 setup-python-uv, read from `main`: the push of #58 to `main` saved the uv cache ([job 130266579757](https://github.com/mlorentedev/ci-workflows/actions/runs/42942226466/job/130266579757)). On #64, `smoke-setup-python-uv` ([job 130288140299](https://github.com/mlorentedev/ci-workflows/actions/runs/42948162863/job/130288140299)) restored it as its base branch's and logged `cache-hit=true` and `python-cache-hit=true`.
- [x] AC5 setup-go-lint per-platform keys: `actions/setup-go` v7.0.0 builds its key in `src/cache-restore.ts` (line 35) as `setup-go-${RUNNER_OS}-${process.arch}-${ImageOS}-go-<version>-<hash>`, and publishes no key output, so no smoke step can check it. `tests/setup-go-lint.bats` holds the pin, and the warm run's log shows the key naming both: `setup-go-Linux-x64-ubuntu24-…`. golangci-lint's result cache is never kept (`skip-cache`, tested, and the log above).

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
