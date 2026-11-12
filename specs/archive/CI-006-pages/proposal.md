---
id: "CI-006-pages"
type: spec
status: archived # draft | implementing | verifying | archived
created: "2026-11-05"
issue: "mlorentedev/ci-workflows#32"   # repo#NNN — GitHub issue / Project item that tracks this spec
tags: [spec, proposal, ci, pages]
template_version: "1.0"
owner: manu
---

# CI-006-pages

## Why

<!-- from issue #32: feat: add a pages reusable workflow -->

Five repositories deploy GitHub Pages with their own `pages.yml`: hive, pdf-modifier, pollex, ts-bridge and
yt-metrics-cli. All five run `npm ci` and `npm run build` in `site/` with Node 22, upload `site/dist`, and
deploy it. No two files are the same:

- pdf-modifier still pins checkout v4, setup-node v4, upload-pages-artifact v3 and deploy-pages v4.
- pollex and yt-metrics-cli leave `persist-credentials` on.
- Only hive builds on pull requests, skips the deploy there, and runs an extra check (`npm run check:links`).
- None sets `timeout-minutes`.

A fix to one copy reaches no other.

## What

- **A reusable `pages` workflow** (`.github/workflows/pages.yml`, GitHub only, ADR-001 §2) with two jobs:
  - `build`: checkout without persisted credentials, setup-node with the npm cache, `npm ci`, the build
    command, an optional check command, and `upload-pages-artifact`.
  - `deploy`: `deploy-pages` to the `github-pages` environment, run only when the event is not a pull request.
- **Inputs, all defaulted** to what the five share: `working_directory` (`site`), `node_version` (`22`),
  `build_command` (`npm run build`), `check_command` (empty, skipped), and `artifact_path` (`site/dist`).
- **Output** `page_url`, from the deploy step.
- Each job declares its own narrow `permissions` and a `timeout-minutes`. The caller owns triggers,
  concurrency and the `permissions` ceiling (AGENTS.md rule 4).
- **Caller fixtures** for the two shapes: hive (pull request builds plus a check command) and ts-bridge
  (push only, defaults).

## Out of scope

- Migrating the five repositories. Each moves in its own pull request, after a release pins this workflow.
- Non-npm builds and Gitea pages. No consumer needs them today.

## Risks / open questions

- **Permissions.** `deploy-pages` needs `pages: write` and `id-token: write`. A caller that grants less fails
  before any step, so the README states the grant and a test checks the job asks for no more.
- **The environment.** `environment: github-pages` is set inside the reusable job. That is mechanism, like
  the review lane in `pr-agent.yml`: a caller that forgot it would lose the deployment record and the
  environment's protection rules.

## Acceptance criteria

1. [x] `pages.yml` is called only (`workflow_call`), defaults every input, declares no secret, hard-codes no
      branch, trigger, workflow-level `permissions` or `concurrency`, and pins every action by full SHA.
      Each rule fails against a fixture that breaks it.
2. [x] `build` asks only for `contents: read`, and `deploy` asks only for `pages: write` and `id-token: write`.
      Both set `timeout-minutes`. `deploy` is skipped on pull requests.
3. [x] The hive and ts-bridge caller fixtures pass only declared inputs and grant what each job asks for.
4. [x] The README documents the inputs, the output, the grant and a caller.
5. [x] After release, one of the five repositories calls the workflow and its deploy stays green (issue #32's
      criterion, verified in that repository's migration pull request).

## References

- ADR: [`docs/adr/adr-001-one-ci-standard-for-every-forge.md`](../../docs/adr/adr-001-one-ci-standard-for-every-forge.md), §2
- Epic: mlorentedev/ci-workflows#8
