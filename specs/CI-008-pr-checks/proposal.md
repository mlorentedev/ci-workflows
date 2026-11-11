---
id: "CI-008-pr-checks"
type: spec
status: draft # draft | implementing | verifying | archived
created: "2026-11-10"
issue: "mlorentedev/ci-workflows#12"   # repo#NNN — GitHub issue / Project item that tracks this spec
tags: [spec, proposal, ci, runner-wait, gates]
template_version: "1.0"
owner: manu
---

# CI-008-pr-checks

## Why

<!-- from issue #12: feat: run the cheap pull request checks as one job -->

Runner wait is the account's bottleneck, not compute. In the 48 hours to 2026-11-11, Ubuntu jobs waited
379 s p50 and 691 s p90 in dotfiles, and 350 s p50 and 663 s p90 in kubelab, for jobs that do 3 to 30 s of
work. The p90 misses the ADR-001 objective (wait p90 ≤ 2 min) by 5.5 to 5.8 times, and the p50 is about
five times the 2026-11-04 baseline's p50 (#14, comment of 2026-11-11). Each cheap check is its own workflow, so each one holds a runner
slot and pays a VM start for seconds of work: dotfiles starts `repo-hygiene`, `knowledge-gate` and
`spec-gate` on every pull request event, kubelab `repo-hygiene` and `spec-gate`. Folding them into one job
gives back one slot per check per event, in every adopter.

## What

- **A composite action `pr-checks`** (`.github/actions/pr-checks/action.yml`) that runs the cheap checks as
  steps of the caller's one job. It installs dotf once, as `hygiene` does, and runs each check behind an
  input:
  - **lessons**: `dotf lessons fmt --check` (exists in dotf 0.79.0);
  - **pinned actions** and the other fleet rules: `dotf lint` (dotfiles#3147);
  - **spec gate** and **knowledge gate**: `dotf gate spec` and `dotf gate knowledge` (dotfiles#3147, see
    the command surface below).
- **Every check runs, whatever the others return.** Each step records its own result in the job summary,
  and a last step fails the job if any check failed. One red check never hides another.
- **Caller fixtures** for dotfiles and kubelab: one workflow with one job replaces `repo-hygiene.yml`,
  `knowledge-gate.yml` and `spec-gate.yml`.
- **`pr-checks` builds on `hygiene`** for the dotf install and the lessons check. A repository that adopted
  `hygiene` (CI-005) moves by changing its `uses:` line and deleting the gate workflows.

### The command surface dotf must offer (dotfiles#3147)

The gates move from vendored scripts (`spec-gate-pr.sh`, `check-spec-gate.sh`, `check-knowledge-gate.sh`)
into dotf, with one contract for every check, so the composite treats them alike:

```
dotf gate spec      --event <path> --base <ref> --head <ref> [--adjacency <tsv>]
dotf gate knowledge --event <path> --base <ref> --head <ref>
dotf lint fleet     --dir <repo>
dotf lessons fmt    --check --dir <dir>
```

- `--event` is a pull request event file. The gates read the number, base, head, labels, body and author
  from it and call no API, so dotf stays forge-neutral.
- **The composite refreshes that file before the gates read it.** "Re-run failed jobs" replays the
  original payload (dotfiles BUG-066, #877), so a gate reading `GITHUB_EVENT_PATH` as is would re-judge the
  pull request as it was before the operator added the escape label or the rationale section, and the
  escape would need an unrelated push. One step in the composite fetches the pull request's current
  labels, body and author from the forge API (`GITHUB_API_URL`, which Gitea's runner also sets) and writes
  a refreshed copy of the event file. It is the only API call, it belongs to the forge adapter, not to
  dotf, and it takes the token as an input, since composites cannot read secrets. A re-run sees the
  current labels and body.
- Exit 0 passes, 1 fails, 2 is a usage or environment error. A failure names the file and line, or the
  missing section, on stderr.
- `--summary <file>` appends a Markdown section for the job summary.

## Out of scope

- `review-attestation` and `pr-agent`. They run on `issue_comment`, `pull_request_review` and
  `workflow_run`, which the cheap checks do not, so they cannot share a job with them.
- `add-to-project` and the other board workflows. The console retires them (kubelab CONSOLE-004).
- The OS matrices (dotfiles#3149, ts-bridge#712) and kubelab's `Tests` job (kubelab#3078). They are the
  heavy jobs; this spec is about the many light ones.
- Writing the dotf commands. They belong to dotfiles#3147.

## Risks / open questions

- **Composite, not a reusable workflow (departs from #12's wording).** #12 asks for a `pr-checks`
  reusable workflow. ADR-001 §2 keeps reusable workflows for families that call GitHub APIs, and these
  checks need none once the gates read the event file. A composite also leaves the job and its check name
  in the caller, so an adopter does not rename a required check by moving a job into a reusable (ADR-001,
  context). Decided here: composite.
- **Required checks change once per adopter, in two steps.** The new job replaces two or three required
  checks, and branch protection waits forever on a required check that no longer runs. So each adopter
  follows the README's `gate` sequence: the first PR adds the `pr-checks` job next to the old workflows,
  under `gate`, and the owner makes `gate` required once it has reported on the default branch; the
  second PR deletes the old workflows, and the owner removes only the checks they replaced, keeping the
  contexts from outside CI such as `review-attestation`.
- **Metadata events re-run every check.** `labeled`, `unlabeled` and `edited` re-evaluate the gates' escape
  hatches today, and in one job they would re-run lessons and lint too. Every check takes seconds, so this
  costs one short job where it now costs three. The concurrency group must not cancel on these events
  (dotfiles BUG-066), which the caller fixture carries.
- **Gitea's pull request API.** The refresh step assumes Gitea's `/repos/{owner}/{repo}/pulls/{n}` returns
  labels, body and author in the GitHub shape. Verified on one Gitea repository before a Gitea adopter.
- **Blocked on dotfiles#3147.** Until the gates exist in dotf, the composite can run only the lessons
  check, which `hygiene` already does. PR 1 here waits for #3147.

## Acceptance criteria

1. [ ] `pr-checks` is a composite of bash steps with no GitHub-only action that installs dotf at a pinned
      version and runs each check behind an input.
2. [ ] With one check failing, every other check still runs, the summary shows each result, and the job
      fails.
3. [ ] The spec and knowledge gates read the pull request from an event file and make no API call. The
      composite refreshes labels, body and author with one API call first, so a re-run of a failed job
      sees the escape label or rationale added since the original event.
4. [ ] dotfiles and kubelab each run one job per pull request event for the cheap checks, in place of two
      or three workflows, with branch protection updated.
5. [ ] After adoption, runner wait for those repositories is recorded against the snapshot in #14.

## References

- ADR-001 (one CI standard), #8 (epic), #14 (runner wait), CI-005 (`hygiene`)
- dotfiles#3147 (dotf gate and lint commands), dotfiles#3149, ts-bridge#712, kubelab#3078
