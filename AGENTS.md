# AGENTS.md

> Instructions for AI coding agents (Claude, Copilot, Cursor, Codex) operating in this repo.

## What this repository is

The fleet's shared CI, referenced by SHA from every consumer
([ADR-042](https://github.com/mlorentedev/dotfiles/blob/main/docs/adr/adr-042-shared-ci-is-referenced-not-copied.md)).
It holds only reusable workflows (`on: workflow_call`) and composite actions,
plus its own `lint.yml`. There is no application code, no build and no release
automation yet. See `README.md` for the consumer contract.

## Rules for every change

1. **No logic here.** Behaviour that a test should cover or a laptop should run
   goes into `dotf` (dotfiles `cli/`); the workflow calls it. A `run:` block
   longer than a few lines is a sign it belongs in `dotf`.
2. **Pin every `uses:` by full 40-character SHA** with the tag as a trailing
   comment (`@<sha> # v7.0.1`). Docker images are pinned by digest.
3. **No `secrets: inherit`.** A reusable workflow declares each secret under
   `on.workflow_call.secrets`; the caller passes each one by name.
4. **No hard-coded branch names, triggers, `permissions` ceilings or
   `concurrency` groups in a reusable workflow.** The caller owns those. A
   reusable workflow may declare narrower job-level `permissions:`, and a
   repository-wide lane may stay inside a job: that lane is mechanism, and a
   caller that forgot it would lose the serialisation.
5. **The public contract is a workflow's `inputs`, `outputs`, `secrets` and
   job ids/names.** Consumers require `<caller job> / <called job>` as a status
   check, so renaming a job, removing an input or adding a required one is a
   breaking change: it needs a new release and the two-PR migration of ADR-042
   §6. Treat it as "touches a public contract" for the Discipline Gate below.
6. **Every PR passes `lint.yml`** (actionlint, which also runs shellcheck on
   each `run:` block). Run `actionlint` locally before pushing.
7. **Everything lands by PR.** The initial scaffold was the only direct commit
   to `main`. Branch protection is declared in dotfiles
   `forge/branch-protection.json`, never edited from here. No auto-merge.

## Spec-Driven Development

**The Lane Decisor Rule:** The agent MUST declare the chosen lane on the VERY FIRST LINE of its response before taking any action (e.g., `Lane: Fast-Track Development`).

**Implementation Lanes:**
- **0. Answer:** Read-only questions, codebase exploration, debugging without writing code.
- **1. Inline Direct:** <30 LOC diff, understood change, single component.
- **2. Fast-Track Development (FTD):** 30–150 LOC, ordinary changes, low ambiguity. 1 document `spec.md`, simple branch, no worktree overhead, observable evidence required.
- **3. Full SDD:** >150 LOC, public contracts, architecture, or high ambiguity. Triad of docs (`proposal.md`, `tasks.md`, `verification.md`).

This repo follows the **Spec-Driven Development per feature** pattern: non-trivial changes are specified before they are implemented.

When the user asks to **create, fill, or archive a spec**, follow this workflow. The `dotf` CLI (installed via dotfiles, on PATH) is the canonical, self-contained interface — run `dotf spec --help` for the full surface.

| Trigger phrase | Action |
|---|---|
| "create a spec for X", "scaffold spec X", "start working on X" | `dotf spec init <feature-id> --issue <N>` |
| "fill in the proposal for X", "help me write the proposal" | edit `specs/<feature-id>/proposal.md` — the Why + acceptance criteria — before writing implementation code |
| "archive spec X", "close spec X" | `dotf spec archive <feature-id> --pr <url>` |

Per-feature specs live at `specs/<feature-id>/` in this repo; archived at `specs/archive/<feature-id>/` (never deleted — audit trail).

**Skip SDD for**: typo fixes, comment-only edits, mechanical refactors, bug fixes <20 lines with obvious cause, doc-only changes.

### Discipline Gate (NON-NEGOTIABLE)

Before creating ANY branch for code changes, Full SDD or FTD is mandatory if ANY apply:

- ~50–300 LOC of production diff (excluding tests, generated files, lockfiles). **The count is
  EXECUTABLE lines** — declarative data, schemas and comment blocks are excluded, because the cap
  rations the control flow a reviewer holds in their head, and a table is read as a table. Excluded
  is not free: declare the breakdown in the PR body whenever total added lines exceed the cap. Nor
  is it "cheap to review" — a registry where one wrong entry silently grants or denies deserves more
  care than most code. SSOT: `00_meta/patterns/pattern-git-workflow.md` §10.
- touches a public contract (API, CLI flag, exported type, alias, file path, deployed config schema)
- adds or removes a dependency
- is the first step of a multi-PR sequence

`<feature-id>` format: `^([A-Z]+[0-9]*(-[A-Z]+[0-9]*)*-[0-9]+[a-z]?(-[a-z0-9-]+)?|[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+)$` (e.g., `AI-001-ollama-public`, `APP-CONFIG-015`, `ADR028-004`, `SDD-012b-guard`, `2026-05-13-cleanup`). This string is `idPattern` in dotfiles `cli/internal/spec/spec.go` verbatim; a drift test asserts every copy matches, so do not reword it.
