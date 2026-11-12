---
id: "lesson-014-a-dependabot-actor-guard-does-not-cover-renovate"
type: lesson
status: active
title: "A dependabot actor guard does not cover Renovate"
created: "2026-11-12"
---

# A dependabot actor guard does not cover Renovate

## Context

The fleet moved dependency pull requests from Dependabot to Renovate (CI-003).
Workflows written in the Dependabot era protect secrets in two ways: they rely
on Dependabot's runs reading the empty Dependabot secret store, or they skip
jobs with `if: github.actor != 'dependabot[bot]'`.

## Problem

Renovate pushes its branch into the repository with the owner's token. Its
pull request is a same-repository run, its actor is the token owner, and it
reads the repository's Actions secrets and whatever `GITHUB_TOKEN` scope the
workflow grants. Neither protection fires. In the #74 inventory, kubelab's
`call-publish` still pushed a Docker Hub image from a Renovate branch, and its
test jobs ran dependency code with a write token granted at workflow level
(kubelab#3344).

## Solution

- When a dependency bot changes, search the workflows for its actor name and
  re-check each guard against the new bot's identity and trigger. A guard that
  names the bot keeps working only while that bot is the only one.
- Guard on the property that matters instead: whether the head branch is a
  dependency update, which forfeits the job rather than granting anything, or
  whether a human wrote the branch.
- Grant `GITHUB_TOKEN` write scopes per job, never at workflow level, so a test
  job that runs dependency code never holds one.
