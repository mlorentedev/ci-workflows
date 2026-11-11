---
tags: [spec, tasks, templates]
created: "2026-11-05"
id: "CI-004-toolchain-setup"
type: spec-tasks
status: active
owner: manu
---

# Tasks - CI-004-toolchain-setup

> TDD order. One task = one focused commit. Tick as you go. Reorder freely while spec is in `draft` state; freeze once you start `implementing`.
>
> **Inline markers** (optional, additive — borrowed from `github/spec-kit`, adapt-not-adopt per #141):
> - `[P]` — this task has **no dependency on another unchecked task**, so it is safe to run in parallel (fan out to a `Workflow`, or just batch). TDD chains (test → implement → refactor of the *same* behavior) are sequential and must NOT carry `[P]`; independent behaviors can.
> - `[AC<n>]` — this task helps satisfy **acceptance criterion #`<n>`** from `proposal.md`. Lets `/spec check` map coverage deterministically; omit it and the check falls back to semantic judgment.

## Setup

- [x] Branch created from main: `feat/issue-10-setup-node`
- [x] `proposal.md` is complete and acceptance criteria are testable
- [x] No open question blocks the code. The Gitea cache question is answered by the pilot (AC4), and the composite must not depend on the answer.

## Implementation

Four pull requests, one per composite, in this order:
1. `setup-node`, which also brings the shared smoke harness;
2. `setup-python-poetry`;
3. `setup-python-uv`;
4. `setup-go-lint`.

PRs 2–4 each get their tasks when they start, reusing PR 1's harness.

### PR 1: `setup-node`

Pins:
- `actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0`
- `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0`

The interface of `.github/actions/setup-node/action.yml`:
- **Inputs.**
  - `version`, default empty.
  - `version-file`, default `.nvmrc`.
  - `working-directory`, default `.`.
  - `playwright`, default `false`.
- **Outputs.**
  - `cache-hit` and `cache-primary-key`, from `actions/setup-node`'s npm cache.
  - `playwright-cache-hit`.
- **Steps.**
  - `resolve` (bash) publishes either `version` or `file`. It fails when both are empty, or when the file is missing.
  - `setup` (`actions/setup-node`) runs with `cache: npm` and `cache-dependency-path: <working-directory>/package-lock.json`.
  - `playwright-version` (bash, only when `playwright == 'true'`) reads the `@playwright/test` or `playwright` version from `package-lock.json`.
  - `playwright` (`actions/cache`) caches `~/.cache/ms-playwright`, keyed on `playwright-${runner.os}-${runner.arch}-<version>`.
- **What stays with the caller.** The composite installs no packages and no browsers: the caller runs `npm ci`, and runs `npx playwright install --with-deps` when `playwright-cache-hit != 'true'`.

Tasks:

- [x] [AC1] Write `tests/setup-node.bats` with failing tests:
  - the input defaults read from `action.yml`;
  - the outputs map to the right steps;
  - the steps run under `bash`;
  - each third-party `uses:` is pinned by a 40-hex SHA with its tag as a comment.

  Run `bats tests/setup-node.bats`. Expected: FAIL, because `action.yml` is missing.
- [x] [AC1] Write `.github/actions/setup-node/action.yml` with the interface above. Expected: those tests pass.
- [x] [AC2] Add failing tests that run the `resolve` script the way `changes.bats` runs its steps:
  - a version input publishes `version`;
  - a present version file publishes `file`;
  - an empty version and a missing file fail with a message naming both.
- [x] [AC2] Implement `resolve`. Expected: the tests pass.
- [x] [AC5] Add failing tests that the Playwright cache key contains `runner.os` and `runner.arch` and the Playwright version, and that the cache step runs only when `playwright == 'true'`. Then implement.
- [x] [AC2] Add tests that `playwright-version` reads the version from a fixture lockfile and fails when neither package is in it. Then implement.
- [x] [AC3] Add the fixture `tests/fixtures/toolchains/node/`, holding `.nvmrc`, a `package.json` with one tiny dependency, and its `package-lock.json`. The cache needs something to store.
- [x] [AC3] In `lint.yml`:
  - a `toolchains` area in `changes` covering `.github/actions/setup-*/**` and `tests/fixtures/toolchains/**`;
  - a `smoke-setup-node` job behind it, which uses `./.github/actions/setup-node` (this checkout, on purpose), runs `npm ci` in the fixture, and prints `cache-hit` and `cache-primary-key`;
  - the job added to `gate`'s `needs`.

  Expected: actionlint clean, and the `callers`/shape tests pass.
- [x] [AC1] Extend `tests/composites-shellcheck.bats`'s minimum step count for the new `run:` steps. Expected: the suite passes.
- [x] [AC3] After merge, record in `verification.md`:
  - the push run on `main` that warmed the cache (`cache-hit=false`);
  - the next run that read it (`cache-hit=true`, with a `cache-primary-key` holding the platform and arch);
  - a pull request reading `main`'s cache as its base branch. PR 2 records it from its own `smoke-setup-node` run.
- [x] [AC4] Gitea pilot: imagesensortool's CI uses `setup-node` at a pinned SHA. Record whether the cache hits there or degrades with the job still green. A missing cache server becomes a kubelab ticket.
- [x] README: a `## setup-node` section with the interface, the caller's `npm ci` and Playwright install, and the Gitea result.

### PR 2: `setup-python-poetry`

Pins:
- `actions/setup-python@6d4fd22b20465ccc0f7354476588e8df7c9ca0e0 # v7.1.0`
- `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0`, as in `setup-node`

The fleet installs Poetry three ways today: `snok/install-poetry` at `latest`, `pip install "poetry>=1.8,<2.0"`, and `pipx install poetry`. The self-hosted runner has no `pipx`. So the composite installs Poetry with `pip` into a venv of its own, at an exact version.

The interface of `.github/actions/setup-python-poetry/action.yml`, for Linux and macOS runners:
- **Inputs.**
  - `version`, default empty.
  - `version-file`, default `.python-version`.
  - `poetry-version`, default empty. It is required, and must be an exact version such as `2.5.1`, because it names a cache key.
  - `working-directory`, default `.`.
- **Outputs.**
  - `cache-hit`, from the project venv's cache.
  - `cache-primary-key`, the project venv's key.
  - `poetry-cache-hit`, from Poetry's own cache.
  - `python-version`, the exact version installed.
- **Steps.**
  - `resolve` (bash) publishes either `version` or `file`, as in `setup-node`. It also fails when:
    - `poetry-version` is not an exact version;
    - `<working-directory>/poetry.lock` is missing.

    It publishes the lockfile's sha256 as `lock-hash`. It does not use `hashFiles`, which returns an empty string for a missing file, so every project would share one key.
  - `setup` (`actions/setup-python`) installs the resolved version, with no cache of its own.
  - `keys` (bash) builds both cache keys from `RUNNER_OS`, `RUNNER_ARCH` and the exact Python version that `setup` installed. A venv points at its interpreter by path, so a venv restored onto another patch release would break.
    - Poetry's key is `poetry-<os>-<arch>-py<python>-<poetry-version>`.
    - The venv's key is `poetry-venv-<os>-<arch>-py<python>-<lock-hash>`.
  - `poetry-cache` (`actions/cache`) caches Poetry's venv.
  - `install-poetry` (bash) creates that venv and runs `pip install poetry==<version>` into it, unless the cache already restored it. It then puts the venv's `bin` on `PATH`, and sets `POETRY_VIRTUALENVS_IN_PROJECT=true`.
  - `venv` (`actions/cache`) caches `<working-directory>/.venv`.
- **What stays with the caller.** The composite installs no project dependencies: the caller runs `poetry install`.

Tasks:

- [x] [AC1] Write `tests/setup-python-poetry.bats` with failing tests:
  - the input defaults;
  - the outputs map to the right steps;
  - the scripts run under bash;
  - the pins;
  - the `setup` wiring.

  Expected: FAIL, because `action.yml` is missing.
- [x] [AC1] Write `.github/actions/setup-python-poetry/action.yml`. Expected: those tests pass.
- [x] [AC2] Add failing tests for `resolve`, then implement it. The tests cover:
  - the version input;
  - the version file;
  - neither, which fails naming both;
  - an empty or non-exact `poetry-version`, which fails;
  - a missing `poetry.lock`, which fails naming its path;
  - `lock-hash` is the lockfile's sha256.
- [x] [AC5] Add failing tests for `keys`, then implement it:
  - both keys hold the OS, the arch and the exact Python version;
  - Poetry's key holds the Poetry version;
  - the venv's key holds the lock hash.
- [x] [AC2] Add failing tests for `install-poetry`, then implement it. They run it against a stub `python` and assert:
  - it installs only when the venv has no `poetry`;
  - it always writes `PATH` and `POETRY_VIRTUALENVS_IN_PROJECT`.
- [x] [AC3] Add the fixture `tests/fixtures/toolchains/poetry/`, generated with Poetry 2.5.1. It holds:
  - `.python-version`;
  - a `pyproject.toml` with `package-mode = false` and one tiny dependency;
  - its `poetry.lock`.
- [x] [AC3] Add a `smoke-setup-python-poetry` job to `lint.yml`. It:
  - runs behind the `toolchains` area;
  - runs `poetry check --lock`, then `poetry install`;
  - asserts that the venv is in the fixture;
  - prints `cache-hit` and `cache-primary-key`;
  - is listed in `gate`'s `needs`.
- [x] [AC1] Raise `tests/composites-shellcheck.bats`'s minimum for the three new `run:` steps.
- [x] [AC3] Record in `verification.md`:
  - `setup-node`'s pull-request hit, from this PR's `smoke-setup-node` run;
  - this composite's warm run and its hit, with the cache scope each one read.
- [x] README: a `## setup-python-poetry` section, saying that a caller on a version range or on `latest` must pick an exact Poetry version.

### PR 3: `setup-python-uv`

Pin: `astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3`, which hive and leaving-denver already use.

`setup-uv` already caches uv's cache, and it can also cache uv-managed Pythons (`cache-python`). Its key (`src/cache/restore-cache.ts`) is `setup-uv-2-<arch>-<platform>-<os>-<python>[-py]-<hash of the glob>`. A glob that matches nothing only warns, and every project then shares the key `…-no-dependency-glob`. So the composite adds three things:
- the version source;
- a required `uv.lock`;
- the cache settings, in one place.

uv builds the venv from its cache by linking, so the venv is not cached.

The interface of `.github/actions/setup-python-uv/action.yml`:
- **Inputs.**
  - `version`, default empty.
  - `version-file`, default `.python-version`.
  - `uv-version`, default empty. When it is empty, `setup-uv` reads `required-version` from `pyproject.toml`, or else installs the latest. It names no cache key, so unlike `poetry-version` it can be left empty.
  - `working-directory`, default `.`.
- **Outputs.**
  - `cache-hit` and `cache-primary-key`, from `setup-uv`'s `cache-hit` and `cache-key`.
  - `python-cache-hit`.
  - `uv-version`.
- **Steps.**
  - `resolve` (bash) publishes `python-version`: either the input, or the first line of the version file. It fails, naming both, when it has neither. It also fails, naming the path, when `<working-directory>/uv.lock` is missing.
  - `setup` (`astral-sh/setup-uv`) runs with:
    - `python-version` from `resolve`, and `uv-version` as `version`;
    - `working-directory`;
    - `enable-cache: "true"`, `cache-dependency-glob: uv.lock`, which `setup-uv` resolves relative to the working directory, and `cache-python: "true"`.
- **What stays with the caller.** The caller runs `uv sync --locked`.

Tasks:

- [x] [AC1] Write `tests/setup-python-uv.bats` with failing tests for the defaults, the outputs, bash, the pin, and the `setup` wiring. Expected: FAIL, because `action.yml` is missing.
- [x] [AC1] Write `.github/actions/setup-python-uv/action.yml`. Expected: those tests pass.
- [x] [AC2] Add failing tests for `resolve`, then implement it. The tests cover:
  - the version input;
  - the version file, first line, trimmed;
  - neither, which fails naming both;
  - a missing `uv.lock`, which fails naming its path.
- [x] [AC3] Add the fixture `tests/fixtures/toolchains/uv/`. It holds `.python-version`, a `pyproject.toml` with one tiny dependency, and its `uv.lock`.
- [x] [AC3, AC5] Add a `smoke-setup-python-uv` job to `lint.yml`. It:
  - runs behind the `toolchains` area;
  - runs `uv sync --locked` and imports the dependency;
  - prints `cache-hit` and `cache-primary-key`;
  - fails when the key does not start with `setup-uv-2-<arch>-<platform>-`;
  - is listed in `gate`'s `needs`.
- [x] [AC1] Raise `tests/composites-shellcheck.bats`'s minimum for the new `run:` step.
- [x] [AC3] Record in `verification.md`:
  - the warm run and the hit for this composite;
  - `setup-python-poetry`'s pull-request hit read from `main`, from this PR's `smoke-setup-python-poetry` run.
- [x] README: a `## setup-python-uv` section.

### PR 4: `setup-go-lint`

Pins:
- `actions/setup-go@b7ad1dad31e06c5925ef5d2fc7ad053ef454303e # v7.0.0`.
- `golangci/golangci-lint-action@ba0d7d2ec06a0ea1cb5fa41b2e4a3ab91d21278a # v9.3.0`.

`setup-go` caches the module cache and the build cache. Its key (`src/cache-restore.ts`, line 35 at v7.0.0) is `setup-go-<RUNNER_OS>-<process.arch>-<ImageOS on Linux>-go-<version>-<hash of the dependency path>`. It throws when the dependency path hashes to nothing, so the composite requires `go.sum` and says so first.

golangci-lint keeps a result cache. That cache reports findings a clean run does not (lessons 353 and 501 in dotfiles), so the composite never caches it: the lint action runs with `install-only` and `skip-cache`, and only the binary is installed. The caller runs `golangci-lint run`, which still reads the build cache.

`setup-go` has no `cache-primary-key` output and no `working-directory` input. So:
- the composite exposes `cache-hit` only;
- AC5 rests on the pinned source line above, a test on the pin and the wiring, and the key read from the warm run's log in `verification.md`. This is a decision, not a gap the review should find later.

The interface of `.github/actions/setup-go-lint/action.yml`:
- **Inputs.**
  - `version`, default empty. The Go version.
  - `version-file`, default `go.mod`. `setup-go` reads its `toolchain` or `go` line.
  - `golangci-lint-version`, default empty. When it is empty, the version comes from go.mod's `tool` line for `github.com/golangci/golangci-lint/v2`. With neither, the step fails rather than install the latest.
  - `working-directory`, default `.`.
- **Outputs.**
  - `cache-hit`, from `setup-go`.
  - `go-version`, from `setup-go`.
  - `golangci-lint-version`, from `resolve`.
- **Steps.**
  - `resolve` (bash) publishes paths relative to the workspace, so the next steps take only its outputs:
    - `go-version`: the input, or empty;
    - `go-version-file`: `<working-directory>/<version-file>`, only when the input is empty, since `setup-go` warns when it gets both;
    - `go-sum`: `<working-directory>/go.sum`;
    - `golangci-lint-version`: the input or go.mod's `tool` line, with a leading `v` added when missing.
    It fails, naming both sources, when it has no Go version or no golangci-lint version. It fails, naming the path, when `go.sum` is missing.
  - `setup` (`actions/setup-go`) with those outputs and `cache: "true"`.
  - `lint` (`golangci/golangci-lint-action`) with the version, `install-only: "true"`, `skip-cache: "true"` and `working-directory`.
- **What stays with the caller.** The caller runs `go build`, `go test` and `golangci-lint run`.

Tasks:

- [x] [AC1, AC5] Write `tests/setup-go-lint.bats` with failing tests for the defaults, the outputs, bash, the pins, the step order, and the wiring of `setup` and `lint`, `skip-cache` included. Expected: FAIL, because `action.yml` is missing.
- [x] [AC1] Write `.github/actions/setup-go-lint/action.yml`. Expected: those tests pass.
- [x] [AC2] Add failing tests for `resolve`, then implement it. The tests cover:
  - the Go version input, which leaves the version file empty;
  - the version file, when the input is empty;
  - neither, which fails naming both;
  - a missing `go.sum`, which fails naming its path;
  - the golangci-lint input, with and without its `v`;
  - go.mod's `tool` line;
  - no golangci-lint version, which fails naming both.
- [x] [AC3] Add the fixture `tests/fixtures/toolchains/go/`: a `go.mod` naming one tiny dependency, its `go.sum`, and a file that uses it and passes golangci-lint's defaults.
- [x] [AC3] Add a `smoke-setup-go-lint` job to `lint.yml`. It:
  - runs behind the `toolchains` area;
  - runs `go build ./...` and `golangci-lint run` in the fixture;
  - prints `cache-hit`, `go-version` and `golangci-lint-version`;
  - is listed in `gate`'s `needs`.
- [x] [AC1] Raise `tests/composites-shellcheck.bats`'s minimum for the new `run:` step.
- [x] [AC3, AC5] Record in `verification.md`:
  - the warm run and the hit for this composite, with the key from the log;
  - `setup-python-uv`'s pull-request hit read from `main` (main saved it in job 130266579757), from this PR's `smoke-setup-python-uv` run.
- [x] README: a `## setup-go-lint` section.

## Closing

- [ ] Every acceptance criterion from `proposal.md` is covered by at least one test or recorded run
- [ ] Every acceptance criterion has a `features.json` entry with a non-vacuous verification command
- [ ] `bats tests/` and `actionlint` pass
- [ ] No unrelated changes in the diff
- [ ] `verification.md` filled in
- [ ] PR opened referencing this spec folder

## Machine-readable features

This spec emits a sibling `features.json` (alongside this file) following [[pattern-feature-list-as-primitive]]. The JSON is the harness-facing contract: each acceptance criterion maps to ≥1 feature with `id`, `behavior`, `verification` (executable command), `state` (lifecycle), and `evidence` (harness-captured output).

**Pass-state gating:** the agent CANNOT write `"state": "passing"` — only the harness, after running `verification` and capturing exit code 0, may set that terminal state. Reviewers must reject PRs where features.json contains `passing` entries with empty `evidence`.

Minimal `features.json` skeleton (drop into `<repo>/specs/CI-004-toolchain-setup/features.json`):

```json
[
  {
    "id": "CI-004-toolchain-setup-f1",
    "behavior": "<one-line copy of an acceptance criterion>",
    "verification": "<single shell command; exit 0 means pass>",
    "state": "pending",
    "evidence": ""
  }
]
```
