# ci-workflows

Shared CI for the `mlorentedev` repositories, referenced rather than copied
([ADR-042](https://github.com/mlorentedev/dotfiles/blob/main/docs/adr/adr-042-shared-ci-is-referenced-not-copied.md)).

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
