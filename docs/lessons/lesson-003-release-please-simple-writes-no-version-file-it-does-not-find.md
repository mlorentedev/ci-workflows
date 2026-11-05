---
id: "lesson-003-release-please-simple-writes-no-version-file-it-does-not-find"
type: lesson
status: active
title: "release-please simple writes no version file it does not find"
created: "2026-11-04"
---

# release-please simple writes no version file it does not find

## Context

This repository releases with release-please, `release-type: simple` (#15).
Its documentation says the simple strategy keeps a `version.txt`, and this
repository has nothing that reads one: the tag is the version, and consumers
carry it in their pin comment.

## Problem

Whether the first release pull request would add a `version.txt` to the root
is not stated in the config docs. A file that appears unplanned becomes a
second place a version is read from, and it drifts from the tag the first time
someone edits it by hand.

## Solution

The answer is in the strategy, not the docs. In release-please v17.11.2 (the
library under release-please-action v5.0.0), `src/strategies/simple.ts` pushes
the version file update with `createIfMissing: false` and the changelog with
`createIfMissing: true`. So `CHANGELOG.md` is created and `version.txt` is only
updated when it already exists. `tests/release-shape.bats` asserts that no
`version.txt` exists and that the config names no `extra-files` or
`version-file`, so one cannot arrive without a test changing.

## Rule

When a tool may write a file, read where it decides to, at the version pinned,
and pin the decision with a test. A default described in prose is a claim; the
`createIfMissing` flag is the behaviour.
