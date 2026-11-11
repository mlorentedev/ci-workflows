---
tags: [spec, tasks]
created: "2026-11-11"
id: "CI-008-pr-checks"
type: spec-tasks
status: active
owner: manu
---

# Tasks - CI-008-pr-checks

> TDD order. One task = one focused commit. `[AC<n>]` maps a task to an acceptance criterion in `proposal.md`.

## Setup

- [x] Branch `docs/ci-008-pr-checks`, proposal written
- [ ] The command surface agreed with the dotfiles session taking dotfiles#3147
- [ ] dotfiles#3147 released in a dotf version (blocks PR 1)

## Implementation

PR 1, the composite (after dotfiles#3147):

- [ ] [AC1] Write `tests/pr-checks.bats` with failing tests: inputs per check, bash steps only, no token, dotf installed through `hygiene`.
- [ ] [AC2] Failing tests that one failing check leaves the others running, writes each result to the summary, and fails the job. Then implement.
- [ ] [AC3] Failing tests that the gate steps pass `--event` the refreshed file and call no API, and that the refresh step, the only API call, replaces labels, body and author in a stale payload with the current ones (stub `curl`). Then implement.
- [ ] [AC1, AC2] Smoke job in `lint.yml` on this repository, with a fixture where one check fails.
- [ ] README section; caller fixtures for dotfiles and kubelab under `tests/fixtures/callers/`.

PR 2..n, adoption (one per repository, merged by the owner):

- [ ] [AC4] dotfiles: one `pr-checks` job replaces `repo-hygiene.yml`, `knowledge-gate.yml` and `spec-gate.yml`; branch protection swap named in the PR.
- [ ] [AC4] kubelab: the same for `repo-hygiene.yml` and `spec-gate.yml`.
- [ ] [AC5] A week after both adoptions, runner wait recorded against the #14 snapshot in `verification.md`.
