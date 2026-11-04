---
id: "lesson-002-actionlint-does-not-read-composite-actions"
type: lesson
status: active
title: "actionlint does not read composite actions"
created: "2026-11-04"
---

# actionlint does not read composite actions

## Context

`lint.yml` runs `actionlint -shellcheck=shellcheck`, which shellchecks every
`run:` block. The `gate` and `changes` composites (issue #9) put most of their
behaviour in `run:` steps of `.github/actions/<name>/action.yml`.

## Problem

actionlint lints workflow files only. Run with no arguments, it reads
`.github/workflows/` and nothing else, and it does not parse `action.yml`. So
the shell of every composite in this repository, `push-gate` included, had never
been shellchecked. `lint` stayed green while it did so.

## Solution

`tests/composites-shellcheck.bats` extracts every `run:` step of every
`.github/actions/*/action.yml` with `yq` and runs `shellcheck -s bash` on it.
The test also requires a minimum number of steps checked, so a glob that matches
nothing fails instead of passing vacuously.

## Rule

A linter that is green has only proved something about the files it read. When
code lives in a file type the linter does not open, add a check for that file
type, and make the check fail when it finds nothing to check.
