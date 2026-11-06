---
id: "lesson-005-dependabot-directory-root-skips-composite-actions"
type: lesson
status: active
title: "Dependabot's directory / skips composite actions"
created: "2026-11-05"
---

# Dependabot's directory / skips composite actions

## Context

While #18 was open, the fleet's `dependabot.yml` files (dotfiles, kubelab, hive,
and others) all configured the `github-actions` ecosystem with
`directory: "/"`. This repository pins `dorny/paths-filter` inside the `changes`
composite, at `.github/actions/changes/action.yml`. #30 then moved the fleet to
Renovate in batches, and #18 closed as superseded.

## Problem

With `directory: "/"`, Dependabot reads `.github/workflows/` and a root
`action.yml`, and nothing else. A pin inside `.github/actions/<name>/action.yml`
is never bumped. Nothing reports the omission: the config is valid, Dependabot
runs, and it bumps the workflows' pins.

## Solution

A repository still on Dependabot during the migration uses `directories:` with a
glob, `["/", "/.github/actions/*"]`. Only `directories` accepts globs;
`directory` does not. Its test checks that every `.github/actions/*/action.yml`
matches an entry, and fails if it finds fewer composites than exist today.

Renovate's `github-actions` manager matches `action.yml` and `action.yaml` at
any depth. The preset's shape test should assert that, so that a change to the
preset cannot drop the composites unnoticed (#35).

## Rule

A repository that adds its first composite action must widen its Dependabot
`github-actions` entry in the same change. Copying `directory: "/"` from another
repository's config only covers the workflows.
