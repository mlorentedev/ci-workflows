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
      dotf_version: 0.78.0
      declared_model: openai/mimo-v2.6-flash
      declared_fallback_models: '["openai/deepseek-v4-flash", "openai/glm5.3-flash"]'
    secrets:
      NAN_API_KEY: ${{ secrets.NAN_API_KEY }}
      PR_AGENT_ANTHROPIC_API_KEY: ${{ secrets.PR_AGENT_ANTHROPIC_API_KEY }}
```

- **Inputs.** `dotf_version`, `declared_model` and `declared_fallback_models` are
  required. `pool` defaults to `embedded`, which makes the dotf pin the pool pin;
  a path reads the caller's own pool. Keep the declared chain equal to the pool.
- **Secrets.** `NAN_API_KEY` is required, `PR_AGENT_ANTHROPIC_API_KEY` optional.
  To grant one, add `ci:<owner>/<repo>` to its consumers in dotfiles'
  `secrets/registry.yaml` and run
  `dotf secrets sync ci --repo <owner>/<repo> <SECRET>`.
- **The caller's files.** `.pr_agent.toml` and `harness/review-attestation.json`,
  both read from its default branch.
- **Permissions.** The job asks for the three scopes above; a caller granting
  less fails the run before any step.

`tests/fixtures/callers/` holds one caller per consuming shape.
`tests/callers.bats` checks each against the workflow's interface, so add a
fixture with a new shape of consumer.

## push-gate

`.github/actions/push-gate` runs `dotf pr gate` and publishes `run`, `mode` and
`reason`. The caller installs `dotf` first. A gate that errors fails the step,
so run it with `continue-on-error: true` where an error must mean a full review.
