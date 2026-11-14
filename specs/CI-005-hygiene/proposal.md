---
id: "CI-005-hygiene"
type: spec
status: implementing # draft | implementing | verifying | archived
created: "2026-11-06"
issue: "mlorentedev/ci-workflows#31"   # repo#NNN — GitHub issue / Project item that tracks this spec
tags: [spec, proposal, ci, hygiene, lessons]
template_version: "1.0"
owner: manu
---

# CI-005-hygiene

## Why

<!-- from issue #31: feat: add a hygiene composite and retire the vendored hygiene scripts -->

`repo-hygiene.yml` runs in 12 repositories in 7 variants, and each copy runs scripts vendored into its
repository: `check-lessons.sh` (11 copies, 4 variants), `check-actions-pinned.sh` and `pin-actions.sh`
(12 copies, 2 variants each). A fix to one copy reaches no other, and nothing detects drift between them
(dotfiles#1573). ADR-001 puts the logic in `dotf` and the CI glue here, so one composite should replace
the vendored scripts.

## What

- **A composite action `hygiene`** (`.github/actions/hygiene/action.yml`) that runs on both forges
  (ADR-001 §2). It installs `dotf` at a pinned version and runs two checks, each skippable by input:
  - **lessons**: `dotf lessons fmt --check`;
  - **pinned actions**: the SHA-pin rule of `dotf lint` (dotfiles#3147), run as
    `dotf lint fleet --rule fleet/sha-pin` (dotfiles#3386, dotf 0.81.0).
- **A caller of a few lines** in each repository replaces `repo-hygiene.yml`'s steps, and the vendored
  scripts are deleted in that repository's own PR.
- **Tests** in `tests/hygiene.bats` and a smoke job in `lint.yml` that runs the composite on this
  repository.

## Out of scope

- Writing the `dotf lint` SHA-pin rule. It belongs to dotfiles#3147.
- Formatting any repository's lessons. Each adopter does that in its own PR (see Risks).
- `pin-actions.sh`, which rewrites refs rather than checking them. Renovate's `helpers:pinGitHubActionDigests`
  (CI-003) pins new refs on its own PRs, and a repository can run `dotf` locally for the rest.
- Fleet adoption PRs. They follow the composite, in batches (dotfiles#3188).

## Risks / open questions

- **Two lesson regimes (blocking).** The vendored `check-lessons.sh` requires a committed
  `docs/lessons/_index.md` and checks that every lesson is listed in it. `dotf lessons fmt --check` does
  the opposite: it fails while an `_index.md` is committed, since `dotf lessons index` renders it on read.
  It also wants every lesson in its frontmatter format. Measured on 2026-11-06 on the default branches:
  hive fails on 121 files, kubelab on 730, and hive, kubelab and pollex all commit `_index.md`. So the
  composite would be red on every adopter until each one migrates. Options:
  - **A.** Adopt `dotf lessons fmt --check` as is. Each adopter's PR runs `dotf lessons fmt`, deletes
    `_index.md`, and fixes the pointer stubs that link it. One large mechanical diff per repository.
  - **B.** Give `dotf lessons` a `check` mode with the vendored script's semantics (unique numbers, every
    lesson indexed) and migrate repositories to the dotf format later, one at a time. Needs a dotfiles
    change before the composite.
  **Decided 2026-11-09: A** (#31, comment 6757339616). The index is derived data, and a formatter that
  converges is the cheaper regime to keep: one migration per repository, then nothing to maintain. B would
  keep a second lesson regime alive in dotf.
- **The pinned-actions rule does not exist yet.** `dotf lint` has only `powershell` in dotf 0.79.0. Until
  dotfiles#3147 lands, the composite ships with the lessons check alone, and adopters keep
  `check-actions-pinned.sh`. The composite declares no input for a check it does not run; the
  pinned-actions input arrives with the rule. AC3 and AC6 wait for #3147. Resolved for AC3: dotf
  0.80.0 shipped the rule, and 0.81.0 adds `--rule` and local composite actions (dotfiles#3386).
- **Installing dotf on Gitea runners.** The composite needs a dotf release binary on both forges. The
  install step must not depend on a GitHub-only action. Resolved: dotfiles is public, so the step fetches
  the release archive and `checksums.txt` with `curl` and checks one against the other, with no token.

## Acceptance criteria

1. [ ] `hygiene` is a composite with no GitHub-only action, installs `dotf` at a pinned version, and runs
      each check behind an input. Each rule fails against a fixture that breaks it.
2. [ ] On a repository whose lessons pass, the lessons check is green; a duplicated lesson number makes
      it red, naming the file.
3. [ ] On a repository with an action pinned by tag, the pinned-actions check is red, naming the line
      (once dotfiles#3147 ships the rule).
4. [ ] The composite runs on one GitHub and one Gitea repository (issue #31, criterion 1).
5. [ ] Every repository that adopted it carries no vendored `check-lessons.sh` or
      `check-actions-pinned.sh` (issue #31, criterion 2).
6. [ ] `dotf lint` reports a repository that still carries them (issue #31, criterion 3).

## References

- ADR: [`docs/adr/adr-001-one-ci-standard-for-every-forge.md`](../../docs/adr/adr-001-one-ci-standard-for-every-forge.md), decisions 1 and 2
- Baseline: `docs/audits/2026-11-ci-baseline.md`, Duplication
- dotfiles: #3147 (fleet rules in `dotf lint`), #1573 (hygiene guards have no SSOT), #2966, #3188 (batched fan-out)
- Epic: mlorentedev/ci-workflows#8
