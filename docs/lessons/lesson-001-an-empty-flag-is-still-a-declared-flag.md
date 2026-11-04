---
id: "lesson-001-an-empty-flag-is-still-a-declared-flag"
type: lesson
status: active
title: "An empty flag is still a declared flag"
created: "2026-11-04"
---

# An empty flag is still a declared flag

## Context

v0.2.0 makes `declared_model` and `declared_fallback_models` optional: left
empty, `dotf pr preflight --pool` reads the NaN chain from the reviewer pool.
The obvious edit keeps the step as it was, `--model "$DECLARED_MODEL"
--fallbacks "$DECLARED_FALLBACK_MODELS"`, and adds `--pool "$POOL"`.

## Problem

An input that defaults to `""` still reaches the command as a flag. dotf decides
"declared" with cobra's `Flags().Changed`, which is true for `--model ""`, so
the obvious edit sends both a chain and a pool, and preflight exits 2 as a usage
error. The step is `continue-on-error`, so the run would go on with no NaN
probe, silently, on every caller that took the default.

## Solution

Build the arguments as a bash array and add the declared flags only when either
input is set (`pr-agent.yml`, step `models`). `tests/preflight-step.bats` runs
that `run:` block against a stub `dotf` and reads the argv it received, so the
pool path and the declared path are both checked against what is actually
passed.

## Rule

When a reusable workflow's optional input feeds a CLI flag, pass the flag only
when the input is set, and test the argv rather than the YAML. An empty string
and an absent flag are different inputs to every parser that tracks `Changed`.
