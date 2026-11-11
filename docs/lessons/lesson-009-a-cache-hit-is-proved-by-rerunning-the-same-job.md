---
id: "lesson-009-a-cache-hit-is-proved-by-rerunning-the-same-job"
type: lesson
status: active
title: "A cache hit is proved by rerunning the same job"
created: "2026-11-11"
---

# A cache hit is proved by rerunning the same job

## Context

Spec CI-004 required each toolchain composite to show a second run reporting
`cache-hit == 'true'` in this repository's smoke jobs (#42, #55, #58, #64).

## Problem

GitHub scopes a cache to the ref that saved it. A pull request run reads its own
ref (`refs/pull/N/merge`) and its base branch, nothing else. So:

- the first run of a new pull request is a miss, unless `main` already saved the
  key;
- a later push to the pull request keeps the same ref and could hit, but a push
  that touches no toolchain path skips the smoke jobs (the `changes` filter) and
  proves nothing;
- `main` saves a key only on its own push run, so a composite's hit "read from
  `main`" can only be shown by the next pull request that runs its smoke.

Waiting for a hit that the scope cannot give cost time in every one of the four
pull requests.

## Solution

- After the warm run, rerun that same job
  (`gh api -X POST repos/<owner>/<repo>/actions/jobs/<id>/rerun`). It reads the
  pull request's own scope and reports the hit. Cite both job ids.
- Record the read from `main` in the next pull request that touches the
  toolchains area, once the merge's push run has saved the key.
- `actions/setup-go` publishes no key output: read the key from the warm run's
  "Cache saved with the key" log line instead.
