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
- **Files a platform needs in each repository** (`dependabot.yml`,
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

`tests/fixtures/callers/` holds one caller per consuming shape.
`tests/callers.bats` checks each against the workflow's interface, so add a
fixture with a new shape of consumer.

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
- **On Gitea**, whether the runner resolves these composites from this
  repository, together with the action paths-filter uses inside them, has not
  been verified yet. Issue #9 tracks the first Gitea consumer.

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

- **Outputs.** `release_created` is `true` when the run created a release;
  `tag_name` (`v1.2.3`) and `version` (`1.2.3`) name it. A publish job gates
  on `release_created`, as above.
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
- **The changelog.** Use `"changelog-type": "github"`. The default changelog
  renders a commit's `Refs owner/repo#N` as `closes`, and merging the release
  pull request then closes those issues.

`tests/fixtures/release-callers/` holds one caller that only releases and one
that publishes; `tests/release-callers.bats` checks them, and this repository's
own caller, against the workflow's interface.

### How this repository is released

`release-please.yml` calls `release.yml` by path on every push to `main`.

1. A merged `feat:` or `fix:` pull request opens or updates the release pull
   request, `chore(main): release X.Y.Z`. Its CI runs because the token is a
   PAT.
2. The owner merges it. That pushes the tag `vX.Y.Z` and publishes the GitHub
   release, with notes generated from the merged pull requests.
3. Dependabot bumps the consumers' pins to the new tag's SHA.

The version comes from the commit types since the last tag. While it is 0.x, a
breaking change (`feat!:` or a `BREAKING CHANGE:` footer) bumps the minor, as
v0.1.0 to v0.2.0 did. The tag is the version: there is no `version.txt`.
