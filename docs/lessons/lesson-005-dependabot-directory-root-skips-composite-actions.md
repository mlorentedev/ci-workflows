---
id: "lesson-005-dependabot-directory-root-skips-composite-actions"
type: lesson
status: active
title: "Dependabot's directory / skips composite actions"
created: "2026-11-05"
---

# Dependabot's directory / skips composite actions

## Context

Issue #18 adds Dependabot for the actions this repository pins. The fleet's
`dependabot.yml` files (dotfiles, kubelab, hive) all configure the
`github-actions` ecosystem with `directory: "/"`. Here, `dorny/paths-filter` is
pinned inside the `changes` composite, at `.github/actions/changes/action.yml`.

## Problem

With `directory: "/"`, Dependabot reads `.github/workflows/` and a root
`action.yml`, and nothing else. A pin inside `.github/actions/<name>/action.yml`
is never bumped. Nothing reports the omission: the config is valid, Dependabot
runs, and it bumps the workflows' pins.

## Solution

Use `directories:` with a glob, `["/", "/.github/actions/*"]`. Only
`directories` accepts globs; `directory` does not. `tests/dependabot.bats`
checks that every `.github/actions/*/action.yml` matches an entry, and it fails
if it finds fewer composites than exist today.

## Rule

A repository that adds its first composite action must widen its Dependabot
`github-actions` entry in the same change. Copying `directory: "/"` from another
repository's config only covers the workflows.
