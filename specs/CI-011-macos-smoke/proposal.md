---
id: "CI-011-macos-smoke"
type: spec
status: implementing # draft | implementing | verifying | archived
created: "2026-11-11"
issue: "mlorentedev/ci-workflows#71"   # repo#NNN — GitHub issue / Project item that tracks this spec
tags: [spec, proposal, ci, toolchains, macos, cache]
template_version: "1.0"
owner: manu
---

# CI-011-macos-smoke

## Why

<!-- from issue #71: feat: smoke the toolchain composites on a macOS runner -->

The four toolchain composites (`setup-node`, `setup-python-poetry`, `setup-python-uv`, `setup-go-lint`) promise a cache key per `runner.os` and `runner.arch` (CI-004 AC5), but every smoke in `lint.yml` runs on `ubuntu-latest`. The CI-004 review found that `setup-node` cached the wrong Playwright path on macOS (#67, fixed in #69) precisely because nothing ran there. A defect of that class reaches every caller at the next tag.

## What

Each of the four smoke jobs in `lint.yml` becomes a matrix over `ubuntu-latest` and `macos-latest` (option (A) in #71):

- The job keeps its id, its `needs: changes` and its `if:` on the `toolchains` area, so `gate` still needs it (ADR-001) and a pull request that touches no toolchain runs no macOS job.
- `fail-fast: false`, so a failure on one OS still reports the other.
- The node fixture depends on `@playwright/test`, the smoke passes `playwright: "true"`, installs Chromium with `npx playwright install chromium`, and checks that a `chromium-*` directory exists under the exported `PLAYWRIGHT_BROWSERS_PATH`.
- The "Report the cache" steps run under the macOS runner's `/bin/bash` 3.2, so they avoid bash 4 expansions such as `${KEY,,}`.

Option (B), a scheduled job outside `gate`, was rejected: it finds a regression after the merge that introduced it, and the issue-opening plumbing it needs is more code than the smoke.

## Out of scope

- Windows runners. The rule allows them on the same terms; add them when a Windows caller exists.
- Launching a browser. The smoke proves the cached path is filled and restored, not that Chromium runs.
- Fleet adoption. `dotf lint` and `dotf fleet apply` route it (epic #8).

## Risks / open questions

- **Wall time.** A macOS leg is slower than Linux, and Chromium adds a download to both node legs. The repository is public, so the minutes cost nothing; the node job's timeout rises to 10 minutes.
- **Bash 3.2.** `shell: bash` on GitHub's macOS images may resolve to Apple's bash 3.2. The composites are already tested under 3.2 by bats (lesson 010); the workflow's own `run:` steps are not, so they are written for 3.2.
- **The dotfiles#3147 rule has no checker yet** in `dotf lint` (it lists only `powershell`). AC3 is shown by the job's `if:`, which a test asserts, not by running a checker that does not exist.

## Acceptance criteria

- [ ] AC1: Each of the four toolchain smokes runs on `macos-latest` against its fixture, and a rerun of the same job reports `cache-hit == 'true'`.
- [ ] AC2: The node smoke passes `playwright: "true"`, so #69's browser path is filled and restored on macOS.
- [ ] AC3: No macOS job runs unconditionally on `pull_request`: every macOS leg is behind the `toolchains` area and stays in `gate`'s needs.

## References

- Issue: mlorentedev/ci-workflows#71; found while working #67
- Fleet rule: mlorentedev/dotfiles#3147
- ADR: `docs/adr/adr-001-*.md` (the single `gate` job)
- Lessons: `docs/lessons/lesson-009-a-cache-hit-is-proved-by-rerunning-the-same-job.md`, `docs/lessons/lesson-010-a-carriage-return-in-ifs-splits-differently-across-bash-versions.md`
