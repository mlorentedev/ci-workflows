---
id: "CI-004-toolchain-setup"
type: spec
status: verifying # draft | implementing | verifying | archived
created: "2026-11-05"
issue: "mlorentedev/ci-workflows#10"   # repo#NNN — GitHub issue / Project item that tracks this spec
tags: [spec, proposal]
template_version: "1.0"
owner: manu
---

# CI-004-toolchain-setup

## Why

<!-- from issue #10: feat: add cached toolchain setup composites -->

Every repository in the fleet installs its toolchain from scratch on every run. The 2026-11 baseline measured, per month:
- about 2.2k min installing Poetry;
- about 2.8k min in setup-go;
- about 1.3k min in golangci-lint.

On top of that, 29 setup-python jobs have no cache, and Playwright adds 22–23 s per run in web and pollex. Without shared composites, each repository fixes caching its own way (Poetry is already installed three different ways), so the cost and the drift between repositories keep growing.

## What

Four composite actions in `.github/actions/`: `setup-node`, `setup-python-uv`, `setup-python-poetry` and `setup-go-lint`.

Each composite:
1. **Installs the version the caller asks for.** It comes from a `version` input, or from the toolchain's version file (`.nvmrc`, `.python-version`, `go.mod`). With neither, it fails with a message. Nothing is hard-coded as a fallback.
2. **Caches what it installs.** The cache key comes from that version and the lockfile. The composite exposes `cache-hit` as an output, so a caller can assert on it.
3. **Behaves the same on GitHub and on Gitea.**

Two composites add something specific:
- `setup-node` can also cache Playwright browsers.
- `setup-go-lint` caches Go modules and the build, but not golangci-lint's results (dotfiles lessons 353 and 501).

They ship as one pull request per composite, starting with `setup-node`.

## Out of scope

- **Fleet adoption.** Moving the callers in web, pollex, hive and the rest happens in each repository's own pull requests, as with `gate` and `changes`. The only adoption here is the Gitea pilot in `personal/imagesensortool`.
- **Docker and trivy caches.** Those belong to #11 (`docker-build`).
- **Moving install logic into `dotf`.** The composites wrap `actions/setup-*` and `actions/cache`. Their only scripts resolve the version and the cache key.

## Risks / open questions

- **The cache on Gitea.** Whether `actions/cache` works on act_runner depends on the runner's cache server configuration. This blocks the design, not the code. The `setup-node` pilot in imagesensortool answers it.
  - Either way, each composite must still install correctly without a cache. A cache failure never fails the job.
  - A missing cache server is a ticket for kubelab, which runs the runner.
- **Proving the cache here.** This repository has no Node, Python or Go, so the proof needs:
  - a fixture in `tests/fixtures/toolchains/<name>/`;
  - a `smoke` job in `lint.yml`, behind a `changes` area and listed in `gate`'s `needs`.

  The hit shows on the second run: a push to `main` warms the cache, and the next pull request reads it. `verification.md` records it with the run.
- **golangci-lint.** Its cache reports findings that a clean run does not (dotfiles lessons 353 and 501). So `setup-go-lint` leaves it off.
- **Cache size.** GitHub keeps 10 GB of cache per repository, and Playwright browsers take hundreds of MB. So the Playwright cache is opt-in, off by default, and keyed on the Playwright version.

## Acceptance criteria

- [x] **Shape tests.** Each composite has a bats test that reads from `action.yml`:
  - its inputs and their defaults;
  - its outputs, including `cache-hit`;
  - every third-party action pinned by a 40-hex SHA with its tag as a comment.
- [x] **Version source.** The version comes from the `version` input or the version file. With neither, the step fails with a message, and a test asserts it. No version is hard-coded.
- [x] **Cache proof.** This repository's `smoke` job runs each composite against its fixture. Its second run reports `cache-hit == 'true'`, with the run cited in `verification.md`.
- [x] **Gitea.** `setup-node` runs on the Gitea runner (imagesensortool). `verification.md` records whether the cache hits there, or degrades without failing the job.
- [x] **Per-platform keys.** Every cache key includes `runner.os` and `runner.arch`, so a runner never restores another platform's binaries. A test asserts it.

## References

- Bitácora board: the GitHub issue / Project item tracking this spec (see the `issue:` frontmatter field)
- Related ADR: `docs/adr/adr-001-one-ci-standard-for-every-forge.md`, practice S5 (cached toolchains), decisions 1 and 2 (logic in `dotf`, composites by default)
- Baseline: `docs/audits/2026-11-ci-baseline.md`, the source of the minutes in Why
- Pins: every third-party action is pinned by SHA. Renovate (#30) bumps them once #35 lands.
- Sister spec: `specs/archive/CI-001-gate-and-changes/` (the Gitea pilot and the smoke-proof pattern)
