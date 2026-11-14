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

- [x] [AC1] (#102) Write `tests/docker-build.bats` with failing tests: the inputs, `load` and `push` exclusive, cache `type=gha` with `scope` defaulting to the image, the overrides for `cache-from` and `cache-to`. Then implement.
- [x] [AC3] (#102, 7 s warm) Smoke jobs `smoke-docker-build` (cold, then warm in a second job with a fresh builder) on a fixture Dockerfile, listed in `gate.needs` and asserted there by a test, as `smoke-hygiene` is. The warm job fails above 30 s.

PR 2, the publish workflow; PR 3, its callers and README:

- [x] [AC2] (PR 2) Failing tests in `tests/docker-publish-shape.bats`: secrets declared by name, no `secrets: inherit`, `security-events: write` only on the job, push by digest with no tag before the gate, one scan and one gate per platform, the SARIF category an input suffixed by platform, the tags applied last. `tests/secrets-contract.bats` picks the workflow up. Then implement.
- [x] [AC4] (PR 3) Caller fixtures for web, kubelab and dotfiles under `tests/fixtures/docker-callers/`, with `tests/docker-callers.bats`. Not under `tests/fixtures/callers/`, which `tests/callers.bats` reads as pr-agent callers only.
- [x] (PR 3) README section, with the cache-size and Gitea notes.

PR 4..n, adoption (one per repository, merged by the owner), after the amendment in the proposal:

- [x] hive: the composite at v0.7.0 in the existing build-then-run job (hive#584).
- [x] (PR A, #114) The composite gains `cache-write` and `labels`, with tests. Spec amendment and lesson 017.
- [x] (PR B, after A merges) `docker-publish.yml` passes `labels`, `cache-from`, `cache-to` and `cache-write` through, pinned at A's merge commit. Then a release.
- [ ] [AC5] dotfiles: the composite with `cache-write` false on pull requests, scope `integration` kept.
- [ ] [AC5] kubelab: `docker-publish.yml` replaces `ci-publish.yml`'s build; `secrets: inherit` dropped. Say which parts of kubelab#3344 it closes.
- [ ] [AC5] web: `docker-publish.yml` with `type=registry` cache for releases; the composite plus web's Trivy gate for pull requests.
- [ ] [AC5] Record hive's and dotfiles' build times, and each kubelab app's cache restore, in `verification.md`.
