# ci-workflows

Shared CI for the `mlorentedev` repositories, referenced rather than copied
([ADR-042](https://github.com/mlorentedev/dotfiles/blob/main/docs/adr/adr-042-shared-ci-is-referenced-not-copied.md)).

## The standard

One CI standard for every repository and every forge, with its decisions in
`dotf` and thin forge adapters here
([ADR-001](docs/adr/adr-001-one-ci-standard-for-every-forge.md)). The
measurements behind it, and the catalog of blocks with their adoption, are in
the [November 2026 baseline](docs/audits/2026-11-ci-baseline.md).

## What belongs here

- **Reusable workflows** (`on: workflow_call`) in `.github/workflows/`.
- **Composite actions** in `.github/actions/<name>/action.yml`.
- This repository's own CI (`lint.yml`), which is not meant to be called.

## What does not

- **Logic.** Anything that also has to run on a laptop, or that a test should
  cover, lives in [`dotf`](https://github.com/mlorentedev/dotfiles) and is
  invoked from here. A workflow in this repository is glue around `dotf`
  calls; it does not grow scripts of its own.
- **Files a platform needs in each repository** (`renovate.json`,
  `CODEOWNERS`, `.coderabbit.yaml`). Those stay per-repository copies, declared
  in the fleet canon and checked for drift.

## How to consume

Pin by full commit SHA, with the release tag as a trailing comment. Never
reference a branch or a tag on its own.

```yaml
jobs:
  review:
    permissions:
      contents: read
      pull-requests: write
    uses: mlorentedev/ci-workflows/.github/workflows/<name>.yml@<40-hex-sha> # vX.Y.Z
    secrets:
      SOME_TOKEN: ${{ secrets.SOME_TOKEN }}
```

- **Secrets are passed by name.** `secrets: inherit` is not used.
- **`on.workflow_call.secrets` is the list a caller needs.** Each reusable
  workflow declares exactly the secrets it reads, and `tests/secrets-contract.bats`
  fails otherwise. Composites read none: they take credentials as inputs. So the
  secrets a repository needs follow from the workflows it calls at its pinned
  SHAs, which dotf reads to report missing and excess CI secrets (dotfiles#3290).
- **The caller owns** triggers, branches, `permissions:` (which caps the called
  workflow) and workflow-level `concurrency:`. A repository-wide lane may stay
  inside a job. Workflows here hard-code no branch name.
- **The check context is `<caller job> / <called job>`.** Renaming a job here
  renames a required check in every consumer, so it is a breaking change.

## pr-agent

`.github/workflows/pr-agent.yml` runs the PR-Agent reviewer and decides with
`dotf pr` at the release the caller pins.

```yaml
name: pr-agent

on:
  pull_request:
    types: [opened, reopened, ready_for_review, synchronize]
  issue_comment:
    types: [created]

permissions: {}

jobs:
  review:
    permissions:
      contents: read
      pull-requests: write
      issues: write
    uses: mlorentedev/ci-workflows/.github/workflows/pr-agent.yml@<40-hex-sha> # vX.Y.Z
    with:
      skip_branch_prefixes: release-please--
    secrets:
      NAN_API_KEY: ${{ secrets.NAN_API_KEY }}
      PR_AGENT_ANTHROPIC_API_KEY: ${{ secrets.PR_AGENT_ANTHROPIC_API_KEY }}
```

- **Inputs.** None is required, so bumping the workflow's pin brings the rest.

  | Input | Default | Meaning |
  |---|---|---|
  | `dotf_version` | the release this tag was tested with | the dotf release installed, without the `v` |
  | `pool` | `embedded` | the dotf pin's pool, or a path in the caller |
  | `declared_model`, `declared_fallback_models` | empty | set both to probe a NaN chain other than the pool's |
  | `skip_branch_prefixes` | empty | branch prefixes whose `pull_request` runs forfeit the review |
  | `declare_unreviewed` | `false` | label and explain an ignored-only PR, and clear a stale label |

- **Skipped branches.** A prefix forfeits the review, never grants one: the
  job still enters the review lane, and `dotf pr reviewable` skips it. A
  `/review` comment is not subject to it.
- **Declaring unreviewed.** `declare_unreviewed: true` needs `escape.label` and
  `escape.section` in the caller's `harness/review-attestation.json`. Without
  them the step reports an error and the review goes on.
- **Secrets.** `NAN_API_KEY` is required, `PR_AGENT_ANTHROPIC_API_KEY` optional.
  To grant one, add `ci:<owner>/<repo>` to its consumers in dotfiles'
  `secrets/registry.yaml` and run
  `dotf secrets sync ci --repo <owner>/<repo> <SECRET>`.
- **The caller's files.** `.pr_agent.toml` and `harness/review-attestation.json`,
  both read from its default branch.
- **Permissions.** The job asks for the three scopes above; a caller granting
  less fails the run before any step.

**From v0.1.0 to v0.2.0.** The job no longer skips `release-please--` branches
itself. A caller that uses release-please passes
`skip_branch_prefixes: release-please--`, or its release PRs start being
reviewed. `dotf_version` and the declared chain can be dropped.

This repository reviews its own pull requests the same way: `review.yml` calls
`pr-agent.yml` by path with only `skip_branch_prefixes`, so the embedded pool
draws, and a change to the reviewer is reviewed by itself.

`tests/fixtures/callers/` holds one caller per consuming shape.
`tests/callers.bats` checks each against the workflow's interface, so add a
fixture with a new shape of consumer.

## pages

`.github/workflows/pages.yml` builds an npm site and deploys it to GitHub Pages
(GitHub only). A pull request builds and runs the check, but neither uploads nor
deploys.

```yaml
name: pages

on:
  push:
    branches: [master]
    paths: ['site/**']
  workflow_dispatch:

permissions: {}

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  pages:
    permissions:
      contents: read
      pages: write
      id-token: write
    uses: mlorentedev/ci-workflows/.github/workflows/pages.yml@<40-hex-sha> # vX.Y.Z
```

- **Inputs.** None is required. The defaults are what the five consumers share.

  | Input | Default | Meaning |
  |---|---|---|
  | `working_directory` | `site` | holds `package.json` and `package-lock.json`; `npm ci` and the commands run here |
  | `node_version` | `22` | the Node.js version |
  | `build_command` | `npm run build` | the build |
  | `check_command` | empty | run after the build, e.g. `npm run check:links`; empty skips it |
  | `artifact_path` | `site/dist` | the built site, from the repository root |

- **Output.** `page_url`, the deployed URL. Empty on a pull request.
- **Permissions.** `build` asks for `contents: read`, and `deploy` for
  `pages: write` and `id-token: write`. A caller granting less fails the run
  before any step.
- **The environment.** `deploy` runs in `github-pages`, so the repository's
  Pages source must be "GitHub Actions".
- **Checks.** A caller requiring status checks names `<caller job> / build`.

`tests/fixtures/pages-callers/` holds the hive shape (pull request builds and a
check) and the ts-bridge shape (defaults); `tests/pages-callers.bats` checks
each against the workflow's interface.

## push-gate

`.github/actions/push-gate` runs `dotf pr gate` and publishes `run`, `mode` and
`reason`. The caller installs `dotf` first. A gate that errors fails the step
and leaves the outputs empty. Where an error must mean a full review, set
`continue-on-error: true`, test `run != 'false'` and treat only
`mode == 'incremental'` as incremental, as `pr-agent.yml` does.

## changes

`.github/actions/changes` reports which areas of the repository an event
touched, so a pull request runs only the jobs it needs (ADR-001 decision 4).

```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: read
      pull-requests: read
    outputs:
      areas: ${{ steps.changes.outputs.areas }}
    steps:
      - uses: actions/checkout@<40-hex-sha> # vX.Y.Z
        with:
          persist-credentials: false
      - id: changes
        uses: mlorentedev/ci-workflows/.github/actions/changes@<40-hex-sha> # vX.Y.Z
        with:
          filters: |
            docs:
              - "docs/**"
              - "**/*.md"
            code:
              - "src/**"
              - "go.mod"

  test:
    needs: changes
    if: contains(fromJSON(needs.changes.outputs.areas), 'code')
    # ...
```

- **The area map.** `filters` takes
  [paths-filter](https://github.com/dorny/paths-filter) YAML, either inline or
  as a path in the repository. Each key is an area and each value is a list of
  globs. The caller owns the map.
- **Outputs.**
  - `areas` is a JSON array of the areas the event touched; it is `[]` when
    none was touched.
  - `full` is `true` when every area is reported.
- **Full runs.** The events listed in `full_run_events` (default:
  `push schedule workflow_dispatch`) skip the filter and report every area. That
  is how the default branch and the nightly run end up running everything.
- **Requirements.**
  - The repository must be checked out first.
  - The job needs `pull-requests: read`, because the filter lists a pull
    request's files through the API.
  - On a full run, the action reads the map with `yq`. If the runner lacks it,
    the step fails instead of reporting no areas.

## gate

`.github/actions/gate` is the one check branch protection requires
(ADR-001 decision 3). It fails unless every job its job needs succeeded or was
skipped, and it names each job that did not.

```yaml
  gate:
    needs: [changes, lint, test]
    if: always()
    runs-on: ubuntu-latest
    timeout-minutes: 2
    permissions: {}
    steps:
      - uses: mlorentedev/ci-workflows/.github/actions/gate@<40-hex-sha> # vX.Y.Z
        with:
          needs: ${{ toJSON(needs) }}
```

- **`if: always()` is required.** Without it, a failed need skips the gate.
  GitHub counts a skipped required check as passing, so the pull request could
  merge red.
- **A job skipped by `changes` passes the gate, and a cancelled job fails it.**
  So does an empty `needs`: a gate that guards nothing must not pass.
- **`gate` sees only its direct needs.** Suppose a job that is listed is skipped
  because a job that is not listed failed. The gate then passes. List every job
  that must block the merge in the gate's own `needs`.
- **Moving branch protection to `gate`.** Do it in two pull requests. The first
  adds the `gate` job next to the checks that are already required. Once `gate`
  has reported on the default branch, the second makes `gate` the only required
  status check and keeps the status contexts that come from outside CI, such as
  `review-attestation`. After that, the jobs behind `gate` can be renamed,
  skipped or moved into this repository without touching branch protection
  again.
- **On Gitea**, both composites work with `uses:` exactly as written above.
  The runner resolves them from github.com, because `DEFAULT_ACTIONS_URL`
  defaults to `github`. It also resolves the paths-filter action nested inside
  `changes`, runs it on node24 and lists the pull request's files through
  Gitea's API. The full-run path finds `yq` in `docker.gitea.com/runner-images`.
  Verified on act_runner v4.1.0 (issue #9). Write the area map under
  `.gitea/workflows/` the same way.
- **This repository uses them too.** `lint.yml` runs `changes`, `lint`, `test`
  and `gate`, pinned to a release rather than to this checkout, so a pull
  request cannot weaken the gate that judges it.

## setup-node

`.github/actions/setup-node` installs Node with a cached npm store, and can also
cache the Playwright browsers (spec CI-004). It installs nothing else: the
caller runs `npm ci` and the Playwright install.

```yaml
    steps:
      - uses: actions/checkout@<40-hex-sha> # vX.Y.Z
        with:
          persist-credentials: false
      - id: node
        uses: mlorentedev/ci-workflows/.github/actions/setup-node@<40-hex-sha> # vX.Y.Z
        with:
          playwright: "true"
      - run: npm ci
      - run: npx playwright install --with-deps
```

- **The version.** `version` wins when it is set. Otherwise the composite reads
  `version-file` (default `.nvmrc`) in `working-directory` (default `.`). With
  neither, the step fails and names both: no version is hard-coded.
- **The npm cache** is `actions/setup-node`'s, keyed on the platform, the arch
  and `<working-directory>/package-lock.json`. So the lockfile must exist.
  `cache-hit` and `cache-primary-key` come from it.
- **Playwright** (`playwright: "true"`, off by default) caches the browsers
  under `playwright-<os>-<arch>-<version>`. The path is the caller's
  `PLAYWRIGHT_BROWSERS_PATH`, or else `~/.cache/ms-playwright` on every OS,
  since Playwright's own default differs on macOS and Windows. The composite
  exports it as `PLAYWRIGHT_BROWSERS_PATH`, so the caller's install writes
  where the cache reads. `PLAYWRIGHT_BROWSERS_PATH=0` fails the step: the
  browsers would sit in `node_modules`, which this cache does not hold. The version is read from
  `@playwright/test`, or else `playwright`, in the lockfile. A lockfile with
  neither fails the step rather than cache under an empty key.
  `playwright-cache-hit` reports the restore. Run
  `npx playwright install --with-deps` on a hit too: it downloads only the
  browsers the cache lacks, so a cache saved from a partial install heals, and
  it installs the system packages the cache never holds.
- **A cache that cannot be reached** is a warning in `actions/cache`, not a
  failure, so the install still runs. On the Gitea runner the cache works: the
  imagesensortool pilot restored the store that `actions/setup-node` had saved,
  because the composite keeps that action's key format (CI-004 AC4).
- **This repository smokes it.** The `smoke-setup-node` job in `lint.yml` runs
  the composite from this checkout against `tests/fixtures/toolchains/node/`,
  and checks that the cache key names the runner's platform and arch.

## hygiene

`.github/actions/hygiene` installs a pinned `dotf` and runs the repository
hygiene checks in it (spec CI-005). It replaces the vendored
`check-lessons.sh`.

```yaml
    steps:
      - uses: actions/checkout@<40-hex-sha> # vX.Y.Z
        with:
          persist-credentials: false
      - uses: mlorentedev/ci-workflows/.github/actions/hygiene@<40-hex-sha> # vX.Y.Z
```

- **The install** downloads `dotf_<version>_linux_<arch>.tar.gz` and
  `checksums.txt` from the public dotfiles release with `curl`, and checks the
  archive against the list. It uses no action and no token, so it runs on
  GitHub and on Gitea. Linux runners only: any other platform fails and names
  itself. `dotf-version` defaults to the release each tag was tested with.
- **lessons** (`lessons: "true"`, on by default) runs
  `dotf lessons fmt --check` on `lessons-dir` (default `docs/lessons`). It fails
  on a lesson out of its canonical form, a lesson number used twice, a wikilink
  to no lesson, and a committed `_index.md`: the index is rendered by
  `dotf lessons index`, never committed. The report is also written to
  `$RUNNER_TEMP/hygiene-lessons.txt` for a later step. An adopter runs `dotf lessons fmt`
  and deletes `_index.md` in the PR that adopts the composite.
- **Pinned actions** are not checked yet. That rule arrives with
  `dotf lint` (dotfiles#3147); until then an adopter keeps its vendored
  `check-actions-pinned.sh`.
- **This repository smokes it.** The `smoke-hygiene` job in `lint.yml` runs
  the composite on this repository's lessons, then on
  `tests/fixtures/lessons/duplicate-number/`, and fails unless that run's own
  report names the duplicate file.

## setup-python-poetry

`.github/actions/setup-python-poetry` installs Python and an exact Poetry, and
caches both Poetry and the project's venv (spec CI-004). It installs no project
dependencies: the caller runs `poetry install`. It runs on Linux and macOS
runners only, since a Windows venv keeps its scripts in `Scripts/`.

```yaml
    steps:
      - uses: actions/checkout@<40-hex-sha> # vX.Y.Z
        with:
          persist-credentials: false
      - id: python
        uses: mlorentedev/ci-workflows/.github/actions/setup-python-poetry@<40-hex-sha> # vX.Y.Z
        with:
          poetry-version: "2.5.1"
      - run: poetry install --no-interaction
```

- **The Python version.** `version` wins when it is set. Otherwise the composite
  reads `version-file` (default `.python-version`) in `working-directory`
  (default `.`). With neither, the step fails and names both.
- **The Poetry version** is required, and must be exact, such as `2.5.1`: it
  names a cache key, so a range or `latest` would install a drifting Poetry
  under a fixed key. A caller that installs `latest` or `>=1.8,<2.0` today picks
  the exact version when it adopts the composite.
- **Poetry** is installed with `pip` into a venv of its own, since the
  self-hosted runner has no `pipx`. That venv is cached under
  `poetry-<os>-<arch>-py<python>-<poetry-version>`. `poetry-cache-hit` reports
  the restore.
- **The project venv** is created in the project, as
  `<working-directory>/.venv`, because the composite sets
  `POETRY_VIRTUALENVS_IN_PROJECT=true`. It is cached under
  `poetry-venv-<os>-<arch>-py<python>-<sha256 of poetry.lock>`. `cache-hit` and
  `cache-primary-key` come from it.
  - `poetry.lock` must exist, or the step fails naming it.
  - On a miss `cache-hit` is empty, not `false`, so compare it with `'true'`.
  - Both keys hold the exact Python version, such as `3.13.9`, not the one the
    caller asked for. A venv points at its interpreter by path, so a venv
    restored onto another patch release would break. `python-version` reports
    the exact version.
- **This repository smokes it.** The `smoke-setup-python-poetry` job in
  `lint.yml` runs the composite from this checkout against
  `tests/fixtures/toolchains/poetry/`. It runs `poetry check --lock` and
  `poetry install`, then imports the fixture's dependency from the venv.

## setup-python-uv

`.github/actions/setup-python-uv` installs uv and a Python, with uv's cache
keyed on `uv.lock` (spec CI-004). It installs no project dependencies: the
caller runs `uv sync --locked`, which links the venv from the cache.

```yaml
    steps:
      - uses: actions/checkout@<40-hex-sha> # vX.Y.Z
        with:
          persist-credentials: false
      - id: python
        uses: mlorentedev/ci-workflows/.github/actions/setup-python-uv@<40-hex-sha> # vX.Y.Z
      - run: uv sync --locked
```

- **The Python version.** `version` wins when it is set. Otherwise the composite
  reads the first line of `version-file` (default `.python-version`) in
  `working-directory` (default `.`), trimmed, a CRLF ending included. With neither, or with an empty file, the
  step fails and names both.
- **The uv version** is `uv-version`. Left empty, `astral-sh/setup-uv` reads
  `required-version` from `pyproject.toml`, or else installs the latest. It
  names no cache key, so unlike `poetry-version` it may be left empty.
- **The cache** is `astral-sh/setup-uv`'s, with uv-managed Pythons included
  (`cache-python`). Its key is
  `setup-uv-2-<arch>-<platform>-<os>-<python>-py-<hash of uv.lock>`.
  `cache-hit` and `cache-primary-key` come from it, and `python-cache-hit`
  reports the Python restore.
  - `uv.lock` must exist, or the step fails naming it. `setup-uv` itself only
    warns when its glob matches nothing, and every project would then share one
    key.
- **This repository smokes it.** The `smoke-setup-python-uv` job in `lint.yml`
  runs the composite from this checkout against `tests/fixtures/toolchains/uv/`,
  runs `uv sync --locked`, and checks that the cache key names the runner's arch
  and platform.

## setup-go-lint

`.github/actions/setup-go-lint` installs Go and golangci-lint, with Go's module
cache and build cache keyed on `go.sum` (spec CI-004). It runs nothing: the
caller runs `go build`, `go test` and `golangci-lint run`.

```yaml
    steps:
      - uses: actions/checkout@<40-hex-sha> # vX.Y.Z
        with:
          persist-credentials: false
      - id: go
        uses: mlorentedev/ci-workflows/.github/actions/setup-go-lint@<40-hex-sha> # vX.Y.Z
        with:
          golangci-lint-version: v2.15.0
      - run: golangci-lint run
```

- **The Go version.** `version` wins when it is set. Otherwise `actions/setup-go`
  reads `version-file` (default `go.mod`) in `working-directory` (default `.`).
  With neither, the step fails and names both.
- **The golangci-lint version** is `golangci-lint-version`, v2 only, with or
  without its `v`. Left empty, it comes from the
  `github.com/golangci/golangci-lint/v2` line of `go.mod`. With neither, the
  step fails rather than install the latest.
- **The cache** is `actions/setup-go`'s. Its key is
  `setup-go-<os>-<arch>-<image>-go-<version>-<hash of go.sum>`, and `cache-hit`
  comes from it. `setup-go` publishes no key, so there is no
  `cache-primary-key` output.
  - `go.sum` must exist, or the step fails naming it: `setup-go` cannot key the
    cache without it.
  - golangci-lint's result cache is never kept. A restored one reports findings
    a clean run does not, so only the binary is installed (`install-only`,
    `skip-cache`). `golangci-lint run` still reuses Go's build cache.
- **This repository smokes it.** The `smoke-setup-go-lint` job in `lint.yml`
  runs the composite from this checkout against `tests/fixtures/toolchains/go/`,
  then `go build ./...` and `golangci-lint run`.

## release

`.github/workflows/release.yml` runs
[release-please](https://github.com/googleapis/release-please) in manifest
mode (ADR-001 decision 6). On each push it opens or updates the release pull
request. Merging that pull request creates the tag and the GitHub release.

```yaml
name: release-please

on:
  push:
    branches: [main]

permissions: {}

concurrency:
  group: release-please
  cancel-in-progress: false

jobs:
  release:
    uses: mlorentedev/ci-workflows/.github/workflows/release.yml@<40-hex-sha> # vX.Y.Z
    secrets:
      RELEASE_TOKEN: ${{ secrets.RELEASE_TOKEN }}

  publish:
    needs: release
    if: needs.release.outputs.release_created == 'true'
    # ... check out needs.release.outputs.tag_name and publish
```

- **Inputs.** None is required.

  | Input | Default | Meaning |
  |---|---|---|
  | `config_file` | `release-please-config.json` | the release-please config, a path in the caller |
  | `manifest_file` | `.release-please-manifest.json` | the manifest holding the current version |
  | `target_branch` | empty: the default branch | the branch the release pull request targets; a caller releasing another branch passes `${{ github.ref_name }}` |

- **Outputs.** `release_created` is `true` when the run created a release;
  `tag_name` (`v1.2.3`) and `version` (`1.2.3`) name it. A publish job gates
  on `release_created`, as above. They describe the root package (`"."` in the
  config); a package under a path is released, but its outputs are not
  forwarded, so a publish job for it would never run.
- **The secret is `RELEASE_TOKEN`**, the one name for release tokens across the
  fleet. It is a fine-grained PAT with contents and pull-requests write on the
  caller. A release pull request opened with `GITHUB_TOKEN` starts no workflow,
  so its required checks never report, and its tag starts no publish workflow.
  To grant it, add `ci:<owner>/<repo>` to its consumers in dotfiles'
  `secrets/registry.yaml` and run
  `dotf secrets sync ci --repo <owner>/<repo> RELEASE_TOKEN`. Without it the
  job fails before release-please runs, and says so.
- **Permissions.** The job asks `GITHUB_TOKEN` for nothing, so a caller's
  `permissions: {}` is enough. A publish job asks for its own.
- **The changelog is release-please's default, with the sections declared.**
  Only `feat`, `fix`, `perf` and `revert` write notes. release-please opens no
  release pull request when the notes are empty, so a `docs:`, `ci:` or
  `chore:` merge does not cut a release. Do not set
  `"changelog-type": "github"`: GitHub's notes are never empty, and every push
  would open a patch release (#24).
- **Squash with the PR title and no body.** release-please-action v5.0.0 ships
  release-please 17.6.0, whose default changelog renders a commit body's
  `Refs owner/repo#N` as `closes`. Merging the release pull request would then
  close those issues. Run `dotf init github` on the caller: it sets
  `squash_merge_commit_title=PR_TITLE` and `squash_merge_commit_message=BLANK`.
  A merge commit or a rebase merge still carries each commit's body.

`tests/fixtures/release-callers/` holds one caller that only releases and one
that publishes; `tests/release-callers.bats` checks them, and this repository's
own caller, against the workflow's interface.

### How this repository is released

`release-please.yml` calls `release.yml` by path on every push to `main`.

1. A merged `feat:` or `fix:` pull request opens or updates the release pull
   request, `chore(main): release X.Y.Z`. Its CI runs because the token is a
   PAT.
2. The owner merges it. That pushes the tag `vX.Y.Z` and publishes the GitHub
   release, with notes from release-please's changelog entry: the `feat`,
   `fix`, `perf` and `revert` merges since the last tag.
3. Renovate bumps the consumers' pins to the new tag's SHA.

The version comes from the commit types since the last tag. While it is 0.x, a
breaking change bumps the minor, as v0.1.0 to v0.2.0 did. Mark it with `!` in
the pull request title (`feat!:`): the squash body is blank, so a
`BREAKING CHANGE:` footer never reaches release-please. The tag is the version: there is no `version.txt`.

## renovate

One weekly run here updates every repository of the owner on GitHub
(`.github/workflows/renovate.yml`). It autodiscovers `mlorentedev/*` and skips
any repository without a `renovate.json`, so adopting Renovate is adding that
file. Dependabot is not used: it does not exist on Gitea.

- **The preset**, `renovate/default.json`, holds the fleet defaults: the
  schedule (all of Monday, Europe/Madrid, so a delayed cron still lands in it), labels, one grouped PR for minor and
  patch updates, majors on their own, actions pinned by digest, a Dependency
  Dashboard, and no automerge. It is plain JSON with no GitHub-only option, so
  the Gitea run extends it too.
- **The engine pin**, `renovate/engine.json`, is the Renovate image and version.
  The run here and the Gitea run both read it, and this repository's own
  Renovate bumps it.
- **The token** is `RENOVATE_TOKEN`, a fine-grained PAT on every repository
  with Contents, Pull requests, Issues and Workflows write, plus Dependabot
  alerts and checks read. It is registered in dotfiles' `secrets/registry.yaml`
  and probed weekly by its `pat-expiry.yml`.

A repository adopts it with a `renovate.json` that pins the preset by tag and
adds only its own managers:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>mlorentedev/ci-workflows//renovate/default#v0.4.0"]
}
```

On Gitea the same line works when the run has `GITHUB_COM_TOKEN` to fetch the
preset from github.com. To run on some repositories now, dispatch the workflow
with `repositories` set, e.g. `mlorentedev/kubelab`.
