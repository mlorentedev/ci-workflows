---
id: "lesson-011-a-grouped-renovate-pr-takes-one-commit-prefix"
type: lesson
status: active
title: "A grouped Renovate PR takes one commit prefix"
created: "2026-11-11"
---

# A grouped Renovate PR takes one commit prefix

## Context

The preset grouped every manager's minor and patch updates into one PR, and gave
GitHub Actions updates the prefix `ci(deps):` so an action bump cuts no release
through release-please (#73, found in garsync#158).

## Problem

A group is one branch and one squash commit, so it carries one prefix. When the
group's title took the Actions prefix, an application `fix(deps):` bump inside
it merged as `ci(deps):`, and release-please released nothing for it. A
per-manager `commitMessagePrefix` reads as per-update, but a group flattens it.

## Solution

- Give updates whose prefix differs a group of their own. The preset now groups
  `github-actions` apart from the general minor and patch group.
- Prove the grouping with the pinned engine, not by reading the config: a
  `--platform=local --dry-run=full` run with the preset as
  `RENOVATE_CONFIG_FILE` lists the branches it would open. The local platform
  ignores an uncommitted `renovate.json`, so pass the config file instead.
- Turning a setting on is proved by a control run without it. Removing the
  `pep621` lock file maintenance block took leaving-denver from four branches to
  three, with `renovate/lock-file-maintenance` the one that went.
- A dry run does not check schedules. `lockFileMaintenance` brings its own,
  `before 4am on monday`, which replaces the repository's window, so the preset
  repeats its Monday window inside the block. Read the default in the engine
  (`dist/config/options/index.js`), not in the docs of another version.
