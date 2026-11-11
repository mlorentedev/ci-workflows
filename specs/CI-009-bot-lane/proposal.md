---
id: "CI-009-bot-lane"
type: spec
status: draft # draft | implementing | verifying | archived
created: "2026-11-11"
issue: "mlorentedev/ci-workflows#13"   # repo#NNN — GitHub issue / Project item that tracks this spec
tags: [spec, proposal, ci, dependencies, renovate, dependabot, merge]
template_version: "1.0"
owner: manu
---

# CI-009-bot-lane

## Why

<!-- from issue #13: feat: add a lane for Dependabot and release pull requests -->

Dependency pull requests wait 21 to 42 hours p50, and the red ones wait indefinitely. On 2026-11-11
garsync#154 had been red and open for 16 days, garsync#157 for 10 and pdf-modifier#227 for 11. Nothing
tells anyone: the check is red on a pull request no human opened. Most of these pull requests are
GitHub Actions digest bumps, a diff a tool wrote and a reviewer cannot add anything to. And the fleet just
moved to Renovate (#30), whose pull requests are authored by the token's owner, so the
`github.actor != 'dependabot[bot]'` tests the workflows rely on (`pr-agent.yml`) no longer tell a
dependency pull request from a human one.

## What

A reusable workflow `bot-lane.yml` (ADR-001 §2: it calls the GitHub API) for three kinds of pull request:
Renovate, Dependabot (security updates still arrive in repositories without `dependabot.yml`) and
release-please. It does three things, each with its own trust rule.

- **Declare the pull request unreviewed, on provenance only.** PR-Agent is skipped and the
  review-attestation escape is set, with a rationale naming the lane. Setting the escape is a grant, not a
  forfeit: it turns a required check green without a review. So it keys only on an author no human can
  be: `dependabot[bot]`, the release-please bot, or a Renovate GitHub App. Never a label, never a branch
  prefix, and never the Renovate PAT's owner, who is also the human. Until Renovate runs as an App, its
  pull requests are reviewed like any other, and the lane only reports them. A test drives a human pull
  request on a `renovate/` branch with the preset's labels, and asserts that no escape is set.
- **Report a red pull request.** When a check fails on a lane pull request, the workflow opens one issue
  for it, or updates the open one, naming the failing checks and the head commit. Once the pull request is
  green, merged or closed, the issue is closed. This half grants nothing, so it may also match on the
  preset's labels or the branch prefix: a human pull request matched by mistake gets an issue, nothing
  more.
- **Merge one class of change without a human click.** Only GitHub Actions digest bumps, and only when the
  content says so; membership in the lane is never enough. That is the "diff nobody wrote" exception:
  - (a) machine-generated and machine-verified: a verifier reads the diff and fails closed unless every
    hunk only replaces `uses: <owner>/<repo>[/<path>]@<sha40> # <tag>` with the same action at
    `@<sha40> # <tag>`, the new SHA is the one the new tag resolves to through the API, the new tag is
    a higher semver than the old one (no downgrade, and versions it cannot compare fail), and every
    changed file is under `.github/workflows/` or is an `action.yml` under `.github/actions/`. Any change
    without a content hunk (a rename, a mode change, a new, deleted or binary file) fails;
  - (b) scope by construction: the merge is `gh pr merge --squash --match-head-commit <verified sha>`, so
    a commit pushed after verification makes it fail. The head pin does not cover the base: a pull
    request retargeted after verification keeps its head SHA. So the job verifies the diff against the
    default branch, re-reads the pull request just before merging, and refuses unless the base is still
    the default branch. `allow_auto_merge` stays false in every repository;
  - (c) the class lives in one file in this repository (`bot-lane/merge-class.json`). Committed tests fail
    if the class widens and if the merging job's `if:` or its `--match-head-commit` changes. A caller can
    only narrow the class (turn merging off, exclude paths), never widen it;
  - (d) production excluded: each caller declares the paths that reach production, and a change to any
    of them is not in the class. The lane does not define production fleet-wide.
- **The merge decision runs from a definition the pull request cannot change.** On `pull_request`, GitHub
  runs the workflow file from the pull request's merge ref. A digest bump may touch `.github/workflows/`,
  so a pull request pushed with the Renovate token could rewrite the caller to skip the verifier. The
  verifying and merging job therefore runs on `workflow_run` after the caller's CI completes, plus a
  schedule as a retry (kubelab's shape). Both read the workflow from the default branch, and a pull
  request whose checks turn green later is still judged. `pull_request_target` alone would fire before
  the checks finish, and never again. It calls the SHA-pinned reusable workflow, never checks out the pull
  request's code, and reads the diff through the API. As belt and braces, the class also excludes the
  caller's own lane workflow file.
- **Release-please pull requests are never merged by the lane.** Release PRs stay the owner's.
- Library and image bumps are never in the merge class. They are reviewed, or merged by the owner.

### Prior art: kubelab's `deploy-merge`

kubelab already runs this exception for mechanical staging deploys (DELIVERY-004, kubelab#1619). Its
`deploy-merge.yml` runs on `workflow_run` and on a schedule, and judges every open pull request from
the default branch's code. It never reads the event payload or a branch name. It merges with
`--match-head-commit` and a release token, so the push workflows still fire, and builds the commit
subject itself, never from the pull request's title or body. Auto-merge stays off, and
`tests/test_deploy_shape_widening.py` pins the merge line. The lane follows the same shape. PR 2
starts by reading that workflow and its toolkit judge, and takes from them what is not
kubelab-specific.

### The command surface dotf must offer

Two things are missing, and both belong in dotf (ADR-001: the logic is dotf's, the workflow wires it):

```
dotf pr declare-unreviewed --diff lane --reason <text>
dotf pr verify-pin-bump --diff <file> --resolve <tsv> [--released <tsv> --min-age <days>] [--exclude <glob>...]
```

- `declare-unreviewed` decides by content today: `empty` sets the escape, `reviewable` clears it. A
  dependency bump to a workflow or a lockfile is `reviewable`, so the lane run as is would clear the
  escape rather than set it. A `lane` value sets it whatever the files are, with the caller's reason.
- `verify-pin-bump` reads a unified diff, the tag-to-SHA table and, when the age check is on, the
  releases' publication dates, all fetched by the workflow. It does not call the API itself, so it stays
  forge-neutral as the gates do (CI-008). A tag missing from either table fails. Exit 0 means every hunk is in the class,
  1 means one is not, naming the file and line, and 2 is a usage error.

## Out of scope

- The bot identity. A GitHub App for Renovate would make the author a real signal again. That decision is
  the owner's (see Risks). The report half and the merge class do not depend on it. Declaring Renovate
  pull requests unreviewed does: it waits for the App.
- Merging anything beyond action digest bumps: library bumps, lockfile maintenance, Docker image digests.
- dotfiles' own move to Renovate (dotfiles#3313).
- Writing the two dotf commands (dotfiles#3317).

## Risks / open questions

Owner decisions, needed before PR 1:

- **Tag re-pointing.** Verifying the new SHA against the tag as it is now accepts a tag an attacker moved,
  the known attack on action pins. A minimum age on the release (Renovate's `minimumReleaseAge`, and the
  verifier checking the release's publication date rather than the commit's, which can be forged) is the
  usual guard. Proposed: 7 days, enforced by the verifier as well as by the preset. The verifier also
  requires an exact `vX.Y.Z` tag in the comment. A floating major tag (`# v4`) moves on every release
  while its release keeps the original date, so the age check would pass for the very re-pointing it is
  meant to catch. Residual risk the owner accepts or not: an exact tag re-pointed after its release still
  carries the old date. The verifier can catch that only between proposal and merge, by comparing the
  tag's SHA to the one Renovate recorded in the pull request.
- **The merging token.** A merge made with `GITHUB_TOKEN` starts no workflow, so the push to the default
  branch would not run release-please or anything else that runs on push. Options: the Renovate PAT,
  which already writes, or a GitHub App with `contents: write` and `pull-requests: write` only.
- **The bot identity** (see Out of scope). It now decides more than membership: without a Renovate App,
  Renovate pull requests cannot be declared unreviewed, because their author is the owner. A GitHub App also gives Renovate its own rate limit, separate
  from the GraphQL pool the owner's sessions share.
- **Production paths per repository.** Candidates: kubelab's deploy workflows and dotfiles'
  `release.yml`. The owner names them; the caller fixture carries them.
- **Opt-in per repository.** The merge half runs only where the caller sets `merge: true`. Should it also
  need a file on the default branch, as the merge grant does, so a caller change alone cannot turn it on?

Other risks:

- **Issue noise.** A flaky check would open and close an issue on every run. The issue is opened only on
  a red head commit, and closed only when the pull request is green, merged or closed, never on a re-run
  in progress.
- **Blocked on dotf.** Until both commands exist, the lane can report red pull requests and nothing else.

## Acceptance criteria

1. [ ] A pull request from a bot author (`dependabot[bot]`, release-please, a Renovate App) is declared
      unreviewed whatever its files, with the lane's rationale. A human pull request on a `renovate/`
      branch with the preset's labels is not. Tests cover both.
2. [ ] A red lane pull request opens one issue within one run, a second red run updates it, and a green
      run closes it. A test asserts all three.
3. [ ] An action digest bump that the verifier accepts merges with `--match-head-commit`. A bump with any
      other hunk, a SHA that does not match its tag, a tag that is not an exact `vX.Y.Z`, a change to the
      caller's lane workflow, or a file on the caller's production list does not merge. Tests cover each.
      A test asserts that the merging job runs on `workflow_run` and a schedule, never on `pull_request` or
      `pull_request_target`, and checks out no pull request code.
4. [ ] The merge class is declared in `bot-lane/merge-class.json`. Committed tests fail if the class
      widens, and if the merging job's condition or its head-commit pin changes. `allow_auto_merge` stays
      false.
5. [ ] Release-please pull requests are declared unreviewed and never merged by the lane. A test asserts
      the merge job cannot run for them.
6. [ ] Caller fixtures for two repositories, one of them with production paths.

## References

- ADR-001 §2 (reusable workflows for GitHub-API families), #8 (epic), #30 (Renovate preset), #13
- The "diff nobody wrote" exception, conditions (a) to (d)
- `dotf pr declare-unreviewed`, `dotf pr reviewable`; `.github/actions/push-gate` (decides whether a push
  is reviewed; it does not verify content)
- dotfiles#3313 (dotfiles' own move to Renovate)
- dotfiles#3317 (the two dotf commands)
- kubelab `deploy-merge.yml` and `toolkit tools deploy-merge` (DELIVERY-004, kubelab#1619): the exception already in production
