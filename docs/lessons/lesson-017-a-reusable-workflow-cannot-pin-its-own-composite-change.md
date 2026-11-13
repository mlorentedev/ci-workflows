---
id: "lesson-017-a-reusable-workflow-cannot-pin-its-own-composite-change"
type: lesson
status: active
title: "A reusable workflow cannot pin a composite change made in the same pull request"
created: "2026-11-12"
---

# A reusable workflow cannot pin a composite change made in the same pull request

## Context

`docker-publish.yml` calls this repository's `docker-build` composite. Inside a
reusable workflow `./` is the caller's checkout, so the call names the
composite by repository and SHA:
`mlorentedev/ci-workflows/.github/actions/docker-build@<sha>`.

## Problem

The SHA has to exist on main before a caller runs the workflow, and the
pull request that changes the composite cannot name its own merge commit.
CI-010 hit this twice. The first time, the workflow pinned a commit from
before the composite gained `push-by-digest`: the input would have been
ignored, nothing pushed, and the scan handed an empty digest. A reviewer
caught it, not a test. The second time, the pin named a commit on the pull
request's branch. The squash merge left that commit off main, so it became
unreachable once the branch was deleted.

## Solution

- Land a composite change first, then pass it through in the workflow with a
  second pull request pinned at the first one's merge commit on main.
- Never pin a commit from a pull request's branch: a squash merge leaves it
  off main.
- Release only after the workflow's pin names a commit on main that has every
  input the workflow passes.
