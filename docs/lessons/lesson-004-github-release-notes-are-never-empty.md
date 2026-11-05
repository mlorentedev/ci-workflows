---
id: "lesson-004-github-release-notes-are-never-empty"
type: lesson
status: active
title: "GitHub release notes are never empty, so release-please releases every push"
created: "2026-11-05"
---

# GitHub release notes are never empty, so release-please releases every push

## Context

#19 set `"changelog-type": "github"` so that a release pull request would close nothing. The default
changelog in release-please 17.6.0, the version release-please-action v5.0.0 ships, renders a commit
body's `Refs owner/repo#N` as `closes`.

## Problem

After #21, a `docs:` change, release-please opened #23, `chore(main): release 0.3.1`. Release-please has
no separate notion of a releasable commit. `buildReleasePullRequest` in `src/strategies/base.ts` returns
nothing only when `changelogEmpty` holds, that is, when the notes have at most one line. The default
changelog hides `docs`, `ci` and `chore`, so for those commits the notes are empty and no release is
cut. GitHub's generated notes list every merged pull request, so they are never empty, and every push
opened a patch release. The shape tests checked the config key. None of them checked what the key
does to a non-releasable commit.

## Solution

Return to the default changelog and declare `changelog-sections`, which settles which types write notes
and therefore which types release. Remove the `closes` at its source: a squash commit takes the PR
title and no body (`dotf init github`, dotfiles#3169), so no commit carries a reference. Upstream,
release-please 17.11.0 already renders references as `refs` (googleapis/release-please#2851). Once an
action release ships it, the squash setting stops being the only guard.

## Rule

When a setting is chosen to avoid one side effect, test the behaviour it controls, not the setting.
Here that behaviour is whether a release is cut. In release-please, notes decide whether a release
happens, so any change to how notes are generated also changes when a release happens.
