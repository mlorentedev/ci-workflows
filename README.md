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
