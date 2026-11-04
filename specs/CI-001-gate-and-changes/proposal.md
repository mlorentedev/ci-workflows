---
id: "CI-001-gate-and-changes"
type: spec
status: implementing # draft | implementing | verifying | archived
created: "2026-11-04"
issue: "mlorentedev/ci-workflows#9"   # repo#NNN — GitHub issue / Project item that tracks this spec
tags: [spec, proposal, ci, composite]
template_version: "1.0"
owner: manu
---

# CI-001-gate-and-changes

## Why

<!-- from issue #9: feat: add the gate and changes composite actions -->

Every repository requires several job names as checks. A job can therefore not be skipped by path, or moved
into a shared block, without renaming a required check: the two-PR migration of ADR-042. And 49 of 84 pull
request workflows have no path filter, so a docs-only pull request runs full CI in 9 repositories. ADR-001
decisions 3 and 4 answer both with one required `gate` check and change detection in front of it. This spec
delivers the two blocks those decisions name.

## What

Two composite actions under `.github/actions/`:

- **`changes`** takes the caller's area map: paths-filter YAML, inline or as a path in the caller.
  - It publishes `areas`, a JSON array of the areas the event touched, and `full`, `true` when every area
    is reported.
  - On a pull request it runs `dorny/paths-filter`, pinned by SHA.
  - On the events in `full_run_events` (default `push schedule workflow_dispatch`) it skips the filter
    and reports every area in the map.
- **`gate`** takes `${{ toJSON(needs) }}` and fails unless every need is `success` or `skipped`, naming
  each one that is not. A missing or empty `needs` fails as well: a gate that guards nothing must not pass.

## Out of scope

- Adopting either block in another repository, on GitHub or Gitea. That is issue #9 acceptance criterion 3:
  it edits the consumers' CI and needs the Gitea runner, so it lands in the consumers' own pull requests.
- A `dotf` verb for change detection. ADR-001 decision 1 points there; issue #9 allows paths-filter, and
  no such verb exists today.
- Moving any repository's branch protection to `gate`.

## Risks / open questions

- **Gitea.** paths-filter runs on `node24` and lists a pull request's files through the GitHub REST API.
  Three things are unverified:
  - whether Gitea's act_runner resolves a nested `uses:` in a composite from this repository;
  - whether it runs `node24`;
  - whether it serves that API.

  Criterion 3 of issue #9 exists to test them.
- **`yq` on the runner.** The full-run path reads the area names with `yq`. GitHub's Ubuntu images ship
  it. A runner without it fails the step with a message; it never reports zero areas.
- **`if: always()`.** A caller's `gate` job without it is skipped when a need fails, and GitHub counts a
  skipped required check as passing. The README says so. A later `dotf lint` rule (dotfiles#3147) can
  check it.

## Acceptance criteria

1. [ ] bats runs both composites' scripts against fixtures: a docs-only change reports only `docs`, a code
      change reports its area, and `gate` passes when every need succeeded or was skipped.
2. [ ] `gate` fails on each of these and names the cause: a failed need, a cancelled need, an empty
      `needs`, invalid JSON.
3. [ ] A push, a schedule and a dispatch report every area as changed, with `full=true`, under test.
4. [ ] paths-filter is pinned by full SHA with its tag as a comment, under test.
5. [ ] The README documents:
      - the area map and the outputs;
      - the `if: always()` rule;
      - how to move branch protection to `gate`.

## References

- ADR: [`docs/adr/adr-001-one-ci-standard-for-every-forge.md`](../../docs/adr/adr-001-one-ci-standard-for-every-forge.md), decisions 3 and 4
- Epic: mlorentedev/ci-workflows#8
