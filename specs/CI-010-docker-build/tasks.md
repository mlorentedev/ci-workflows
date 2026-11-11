---
tags: [spec, tasks]
created: "2026-11-11"
id: "CI-010-docker-build"
type: spec-tasks
status: active
owner: manu
---

# Tasks - CI-010-docker-build

> TDD order. One task = one focused commit. `[AC<n>]` maps a task to an acceptance criterion in `proposal.md`.

## Setup

- [x] Branch `docs/issue-11-docker-build-spec`, proposal written
- [ ] Owner review of the two-layer split (composite plus publish workflow)

## Implementation

PR 1, the composite:

- [ ] [AC1] Write `tests/docker-build.bats` with failing tests: the inputs, `load` and `push` exclusive, cache `type=gha` with `scope` defaulting to the image, the overrides for `cache-from` and `cache-to`. Then implement.
- [ ] [AC3] Smoke jobs `smoke-docker-build` (cold, then warm in a second job with a fresh builder) on a fixture Dockerfile, listed in `gate.needs` and asserted there by a test, as `smoke-hygiene` is. The warm job fails above 30 s.

PR 2, the publish workflow:

- [ ] [AC2] Failing tests in `tests/docker-publish-shape.bats`: secrets declared by name, no `secrets: inherit`, `security-events: write` only on the job, push by digest with no tag before the gate, one scan and one gate per platform, the SARIF category an input suffixed by platform, the tags applied last. `tests/secrets-contract.bats` picks the workflow up. Then implement.
- [ ] [AC4] Caller fixtures for web, kubelab and dotfiles under `tests/fixtures/docker-callers/`, with `tests/docker-callers.bats`. Not under `tests/fixtures/callers/`, which `tests/callers.bats` reads as pr-agent callers only.
- [ ] README section, with the cache-size and Gitea notes.

PR 3..n, adoption (one per repository, merged by the owner):

- [ ] [AC5] dotfiles and hive: the composite in the existing build-then-run job.
- [ ] [AC5] web and kubelab: `docker-publish.yml` replaces `build-image.yml` and `ci-publish.yml`'s build. kubelab drops `secrets: inherit`.
- [ ] [AC5] Record dotfiles' integration build time, and each kubelab app's cache restore, in `verification.md`.
