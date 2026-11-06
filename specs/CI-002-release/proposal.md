---
id: "CI-002-release"
type: spec
status: verifying # draft | implementing | verifying | archived
created: "2026-11-04"
issue: "mlorentedev/ci-workflows#15"   # repo#NNN — GitHub issue / Project item that tracks this spec
tags: [spec, proposal, ci, release]
template_version: "1.0"
owner: manu
---

# CI-002-release

## Why

<!-- from issue #15: feat: release this repository with release-please and share the workflow -->

The fleet runs 10 release workflows in 10 variants, with four names for the release token secret, and one of
them (pollex) failed 16 of 16 runs in the baseline window. This repository is tagged by hand, so its own
consumers depend on someone remembering to tag. ADR-001 decision 6 says this repository releases with
release-please and semver tags, and that one secret name is used for release tokens across the fleet.

## What

- **A reusable `release` workflow** (`.github/workflows/release.yml`, job `release-please`). It runs
  release-please in manifest mode with the caller's `RELEASE_TOKEN` and publishes `release_created`,
  `tag_name` and `version`, so a caller can gate a publish job on them.
- **This repository is its first caller** (`.github/workflows/release-please.yml`, on push to `main`). A
  `feat:` or `fix:` merge opens or updates a release pull request; the owner merges it, and that creates
  the tag and the GitHub release.
- **The config** bootstraps from `v0.2.0` (manifest `{".": "0.2.0"}`), uses `release-type: simple` with no
  version file, and release-please's own changelog with `changelog-sections` that make only `feat`, `fix`,
  `perf` and `revert` releasable (amended by #25; the first config used `changelog-type: github`).
- **Two caller fixtures**: dotfiles (release only; its tag push starts the publish workflow) and pollex (a
  publish job gated on `release_created`).

## Out of scope

- Migrating any consumer to the reusable workflow. Each migration lands in the consumer's own pull request.
- A `dotf` verb for release logic. The workflow carries no logic beyond a missing-token check.
- Porting dotfiles' release-PR-body sanitizer (rule 1). Squash commits here carry the PR title and a blank
  body, so the changelog has no reference to render as `closes` (#25; dotfiles#3198 removes the sanitizer).
- Making `RELEASE_TOKEN` available: dotfiles#3156 registers it and the owner syncs it.

## Risks / open questions

- **The token.** A release PR opened with `GITHUB_TOKEN` starts no workflow, so `lint` never reports on it.
  `RELEASE_TOKEN` is a fine-grained PAT; its write permissions are proven by the first run. Without it the
  first run after merge goes red, so the secret must exist before this PR merges.
- **The bootstrap tag.** release-please finds the last release by the manifest version: the GitHub release
  list holds only v0.1.0, so it falls back to the tag `v0.2.0`. The owner creates that tag at `892309f`
  before merging. Without it release-please would walk the whole history.
- **Closing references.** The default changelog renders a squash body's `Refs mlorentedev/dotfiles#N` as
  `closes ...`, so merging a release PR would close issues in dotfiles (dotfiles CI-005). The GitHub
  changelog avoided that but is never empty, so every push opened a release (#24, lesson 004). #25 went
  back to the default changelog: squash commits carry the PR title and a blank body, so there is no
  reference to render. A merge commit or a rebase merge still carries a body.
- **Pre-1.0 breaking changes.** `bump-minor-pre-major: true` makes a breaking change a minor bump while the
  version is 0.x, as v0.1.0 to v0.2.0 already was. ADR-001 decision 6 calls a breaking change "a major
  release": below 1.0.0 the minor is that slot under semver. Removing the key moves the next breaking
  change to 1.0.0.

## Acceptance criteria

1. [x] `release.yml` is called only (`workflow_call`), requires `RELEASE_TOKEN`, defaults every input,
      publishes `release_created`, `tag_name` and `version`, hard-codes no branch, `permissions` or
      `concurrency`, and pins release-please-action by full SHA. Each rule fails against a fixture that
      breaks it.
2. [x] A missing `RELEASE_TOKEN` fails the job before release-please runs, naming the remedy.
3. [x] The config bootstraps from 0.2.0, uses release-please's own changelog with only `feat`, `fix`,
      `perf` and `revert` visible, and writes no version file.
4. [x] Caller fixtures for dotfiles and pollex, plus this repository's own caller, pass only declared
      inputs and secrets and pass `RELEASE_TOKEN` by name. The pollex fixture gates its publish job on
      `release_created`.
5. [x] The README documents the secret name, the inputs and outputs, and how a release happens here.
      AGENTS.md no longer says there is no release automation.
6. [x] After merge, merging a `feat:` commit opens a release pull request; the owner merging it creates
      the tag and the GitHub release (issue #15 criterion 1, verified on the first run).

## References

- ADR: [`docs/adr/adr-001-one-ci-standard-for-every-forge.md`](../../docs/adr/adr-001-one-ci-standard-for-every-forge.md), decision 6
- Epic: mlorentedev/ci-workflows#8
- Token grant: mlorentedev/dotfiles#3156
