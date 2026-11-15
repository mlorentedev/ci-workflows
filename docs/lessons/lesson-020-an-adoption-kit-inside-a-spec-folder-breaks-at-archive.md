---
id: "lesson-020-an-adoption-kit-inside-a-spec-folder-breaks-at-archive"
type: lesson
status: active
title: "A file that outlives its spec cannot live in the spec's folder"
created: "2026-11-15"
---

# A file that outlives its spec cannot live in the spec's folder

## Context

CI-007 moved twelve repositories onto the shared `pr-agent.yml`. Its adoption
kit (the caller, the class paragraph and the registry block) was written into
`specs/CI-007-fleet-pr-agent/kit/`, next to the tasks that used it.

## Problem

The kit did not stay a spec artifact. `tests/class-guard.bats` and
`tests/review-concurrency.bats` read it, and the guard's error message in the
shared workflow told adopters to copy it from that path. Archiving moves the
folder to `specs/archive/`, so the archive commit itself would have turned
`bats tests/` red on main and pointed every adopter's error at a 404. Nothing
showed it until the pre-archive review simulated the move. `tests/hygiene.bats`
had the same latent break, reading `specs/CI-005-hygiene/features.json`.

## Solution

- The kit moved to `pr-agent/` at the root, beside `renovate/`, which is where
  this repository keeps what adopters consume.
- `tests/specs.bats` fails when a workflow or a test names a path inside an
  active spec folder (`specs/<ID>-…`), with a case proving the check fires.
  `specs/archive/` paths are allowed: they do not move again.
- Before a spec archives, ask which of its files something outside the folder
  reads. Those were never the spec's.
