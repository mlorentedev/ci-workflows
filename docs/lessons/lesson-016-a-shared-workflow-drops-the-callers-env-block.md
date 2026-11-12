---
id: "lesson-016-a-shared-workflow-drops-the-callers-env-block"
type: lesson
status: active
title: "Moving to a shared workflow drops whatever the old env block set"
created: "2026-11-12"
---

# Moving to a shared workflow drops whatever the old env block set

## Context

CI-007 replaced twelve copies of the PR-Agent steps with a caller of the shared
`pr-agent.yml`. Each old copy configured PR-Agent through `CONFIG__*` and
`PR_REVIEWER__*` variables in its `env:` block, as well as through
`.pr_agent.toml`.

## Problem

The caller passes no `env:` to the shared job, so every setting the old block
held disappears when it is deleted, with no error. pdf-modifier's old workflow
set `persistent_finding_state` to false there; the shared workflow does not set
it, so the adopter PR turned the feature back on without anyone choosing to.
Reading the new caller and the toml shows nothing missing: the loss is only
visible in what was deleted.

## Solution

- Before deleting an old workflow, list its `env:` keys and, key by key, check
  where each one now comes from: the shared step, the toml, or nowhere.
- Move a setting that only one repository needs into its `.pr_agent.toml`
  (pdf-modifier kept `persistent_finding_state = false` there). Move a setting
  the whole fleet needs into the shared step, where it overrides every toml.
- Say in the adopter PR which keys moved where, so the reviewer can check the
  list instead of finding the gap later.
