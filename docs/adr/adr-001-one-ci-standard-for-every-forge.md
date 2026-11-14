---
id: "ADR-001-one-ci-standard-for-every-forge"
type: adr
status: proposed
owner: manu
date: "2026-11-04"
supersedes: []
extends: [mlorentedev/dotfiles adr-042-shared-ci-is-referenced-not-copied]
issue: mlorentedev/ci-workflows#8
tags: [architecture, decision, ci, fleet, gitea, gitlab]
created: "2026-11-04"
---

# ADR-001: One CI standard for every forge, with its logic in dotf

## Context

The baseline in [`docs/audits/2026-11-ci-baseline.md`](../audits/2026-11-ci-baseline.md) measured 24 GitHub
repositories and the repositories on the self-hosted Gitea forge between 2026-10-05 and 2026-11-04:

- The same workflow exists as many diverging copies: 20 copies of each board workflow, 18 of them carrying
  two bugs fixed elsewhere; 14 copies of pr-agent in 12 variants; 10 release workflows, all different.
- CI on the final commit is 5.9% of a pull request's open-to-merge time, but every iteration waits for full
  CI. One job, kubelab's `Tests`, is about 40% of all job-minutes. Small workflows cost runner slots, not
  minutes: jobs wait up to 7 minutes for a slot on GitHub and 23–29 minutes on the 2-slot Gitea runner.
- Required checks block every migration: moving a job into a reusable workflow renames its check to
  `<caller job> / <called job>`, which ADR-042 handles with a two-PR migration per repository.

The repositories live on GitHub and Gitea, and GitLab may follow. The three forges share no workflow syntax
that is complete on all of them: GitHub runs reusable workflows and composite actions; Gitea's runner runs
composite actions and only a limited form of reusable workflow, which holds a runner slot; GitLab has
`include:` and CI components and no `uses:` at all.

## Decision

1. **Decisions live in `dotf`; YAML is an adapter.** Anything that decides (what changed, whether a gate
   passes, what a report says) is a `dotf` verb with tests, runnable on a laptop (ADR-042 class 3). A forge
   file only installs `dotf`, calls it, and maps its outputs. A new forge is a new adapter, not a rewrite.
2. **Composite actions by default, reusable workflows only where a family exists on GitHub alone.** Anything
   a Gitea repository must run (change detection, the gate, toolchain setup, hygiene) is a composite action.
   Reusable workflows are kept for families that call GitHub APIs: pr-agent, release, the bot lane.
3. **One required check per repository: `gate`.** Every repository's CI ends in a caller-side job named
   `gate` that requires its `needs` to have succeeded or been skipped. Branch protection requires `gate`
   (plus status contexts such as `review-attestation`). Jobs behind it can then be skipped by change
   detection or moved into this repository in one pull request, because their names are no longer contracts.
   (Amended 2026-11-14, dotfiles#3447: the job is `gate` unless another workflow in the repository already
   reports a `gate` context, as a `spec-gate.yml` whose job is `gate` does. It is then `<workflow>-gate`,
   for example dotfiles' `ci-gate`, because two workflows reporting one context make the required check
   ambiguous. The rule is one required aggregate per workflow, not one name.)
4. **Pull requests run what they touch; the default branch runs everything.** Change detection decides which
   jobs run on a pull request. Push to the default branch and a nightly schedule run the full suite and the
   full OS matrix. The skip logic is tested like any other code.
5. **Every rule is checked by `dotf lint`, and adoption is applied by `dotf fleet apply`.** The checker reads
   `.github/workflows`, `.gitea/workflows` and, later, `.gitlab-ci.yml`. A practice a repository lacks is a
   lint finding; `dotf fleet apply` turns it into a pull request in that repository. Nobody hand-edits a fleet
   of copies again. The checker is `dotf lint fleet` (dotfiles 0.80.0); its rules, exceptions file and CI
   usage are in dotfiles'
   [`docs/runbooks/guide-fleet-lint.md`](https://github.com/mlorentedev/dotfiles/blob/main/docs/runbooks/guide-fleet-lint.md).
6. **Versioning.** This repository releases with release-please and semver tags. Consumers pin by full SHA
   with the tag as a comment, and Renovate bumps the pins (amended 2026-11-06, CI-003: Renovate replaces
   Dependabot on both forges, since Gitea has no Dependabot). Removing or renaming an input, an output, a
   secret or a job id is a major release. One secret name is used for release tokens across the fleet.
7. **Specs and ADRs for a block live here.** A block of this repository gets its spec under `specs/` and its
   decisions under `docs/adr/`. A `dotf` verb keeps its spec in dotfiles, and the two link to each other.
8. **Measured, not felt.** A scheduled report publishes per repository the p50/p90 of pull request feedback
   time and of runner wait, against two objectives: feedback p90 ≤ 10 minutes for the busiest repositories,
   and runner wait p90 ≤ 2 minutes on GitHub and ≤ 5 minutes on Gitea. The first report sets the baseline.
9. **Board workflows are retired, not centralised.** Work items move to forge labels read by the platform
   console (kubelab CONSOLE-004). Until then the existing copies get only the minimal fix for the two known
   bugs, applied by `dotf fleet apply`; no reusable is built for them.

## Consequences

- One improvement reaches every repository: it changes a `dotf` verb or a block here, and the pins move.
- Gitea adoption depends on composite actions resolving from this repository on the Gitea runner. That is
  verified on one Gitea repository before any other adopts a block.
- Repositories with several required checks need one migration to their aggregate (`gate`, or `<workflow>-gate`). After it, no further migration
  renames a required check.
- The fleet stops being configured by hand: anything not expressible as a lint rule plus an apply step does
  not belong to the standard.

## Alternatives rejected

- **One reusable workflow for everything.** It does not run on Gitea in full and does not exist on GitLab.
- **Logic in this repository's YAML or scripts.** It cannot run locally or on another forge, and it repeats
  the copies this decision removes.
- **A reusable for the board workflows.** The board is being replaced; building it would be retired work.
