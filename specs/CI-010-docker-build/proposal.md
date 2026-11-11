---
id: "CI-010-docker-build"
type: spec
status: draft # draft | implementing | verifying | archived
created: "2026-11-11"
issue: "mlorentedev/ci-workflows#11"   # repo#NNN — GitHub issue / Project item that tracks this spec
tags: [spec, proposal, ci, docker, cache, runner-wait]
template_version: "1.0"
owner: manu
---

# CI-010-docker-build

## Why

<!-- from issue #11: feat: add a docker-build reusable workflow with layer cache -->

Image builds are the slowest steps in the fleet's pull request runs, and half of them start cold.

- **No layer cache.** dotfiles builds its integration container with plain `docker build` (3.4 min p50, on every pull request that touches code), and so does hive.
- **A cache the builds overwrite.** kubelab's `ci-publish.yml` builds several apps (api, web, errors) with `cache-from: type=gha` and `cache-to: type=gha,mode=max` but no `scope`, so they all share buildx's default scope and each build overwrites the previous app's cache.
- **Three copies of the same build.** web (`build-image.yml`) and kubelab (`ci-publish.yml`) keep two buildx and Trivy implementations that agree nearly line for line, and their pins drift apart: three different `login-action` SHAs, and two `upload-sarif` SHAs.

With runner wait the account's bottleneck (#14), a cold build holds a slot for minutes.

## What

There are two layers, following ADR-001 §2: a composite by default, and a reusable workflow only for the part that calls GitHub APIs.

- **A composite action `docker-build`** (`.github/actions/docker-build/action.yml`) that runs inside the caller's job:
  - it sets up buildx and builds with `docker/build-push-action`;
  - the cache is `type=gha` with a `scope` that defaults to the image name, so two images in one repository never share a scope;
  - it takes `context`, `file`, `image`, `tags`, `build-args`, `platforms`, and either `load` or `push`, and outputs the digest;
  - it does not log in: the caller does, or uses the workflow below.

  Because it runs in the caller's job, a build-then-run job keeps its shape. dotfiles' integration test and hive's smoke test build, then `docker run` the image they just built, which a separate job could not do without exporting the image.
- **A reusable workflow `docker-publish.yml`** for registries and scans, the part that needs `security-events: write`. It logs in, runs the composite with `push`, scans with Trivy, uploads the SARIF report under a caller-named category, and fails on a CRITICAL finding. That is web's `build-image.yml` with kubelab's tag inputs.
  - Registry credentials are passed by name, as `registry_username` and `registry_token`, with `secrets: inherit` never used. `tests/secrets-contract.bats` already enforces it.
  - kubelab's `release.yml` drops its `secrets: inherit` when it adopts.

## Out of scope

- **Tag computation.** kubelab's `docker_tags` step (pre-release, rc, final) stays in the caller and is passed in as `tags`.
- **Multi-arch manifest promotion** (`docker buildx imagetools create` in both release workflows). It is a release concern, and can be a second composite later.
- **Gitea.** See Risks: `type=gha` needs the GitHub cache service.
- **Signing and SBOM attestations.** No adopter does them today.

## Risks / open questions

- **Cache size.** GitHub keeps 10 GB of cache per repository and evicts the least recently used entries. `mode=max` on a two-platform build can approach that in kubelab. The composite exposes `cache-mode`, defaulting to `max`. The README states the trade-off, and kubelab measures its usage after adopting.
- **Gitea.** `type=gha` talks to GitHub's cache service, and whether Gitea's runner cache server speaks its protocol is unverified. Until a Gitea adopter checks it, the composite takes `cache-from` and `cache-to` overrides (for example `type=registry`), and the README marks the default as GitHub-only.
- **Trivy's pin.** Both adopters pin `aquasecurity/trivy-action` v0.36.0 by SHA. The workflow pins it once, and Renovate's digest pinning moves it. A Trivy outage fails publishing, so the CRITICAL gate stays a separate step with its own pin, as in web, and the SARIF upload keeps `continue-on-error`.
- **The fixture location departs from #11.** #11 asks for fixtures in `tests/fixtures/callers/`, but `tests/callers.bats` reads every file there as a pr-agent caller. The fixtures go to `tests/fixtures/docker-callers/`, with their own test, as `pages-callers` and `release-callers` do.

## Acceptance criteria

1. [ ] `docker-build` is a composite that builds with buildx, caches with `type=gha` scoped by default to the image name, and either loads or pushes. A test asserts the scope default, and asserts that no input value leaves the scope empty.
2. [ ] `docker-publish.yml` logs in, pushes through the composite, uploads the Trivy SARIF report under the caller's category, and fails on a CRITICAL finding. It reads registry secrets by name only, and `tests/secrets-contract.bats` covers it.
3. [ ] A warm rebuild with no source change takes under 30 s in this repository's CI. A smoke job builds a fixture image, and a second job with a fresh builder rebuilds it from the `gha` cache. The test asserts the time and the cache hit.
4. [ ] Caller fixtures for web (publish) and dotfiles (build, then run), under `tests/fixtures/docker-callers/`, checked by their own test.
5. [ ] After adoption, dotfiles' integration build time is recorded against its 3.4 min p50, and kubelab's apps each restore their own cache.

## References

- ADR-001 §2 (composites by default), #8 (epic), #14 (runner wait)
- web `.github/workflows/build-image.yml`, kubelab `.github/workflows/ci-publish.yml` and `release.yml`, dotfiles `ci.yml` (`integration` job), hive `ci.yml` (`docker` job)
- kubelab#3299 (the unscoped cache, fixed on its own)
