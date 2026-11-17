---
id: "lesson-021-a-digest-without-a-tag-is-bumped-to-latest"
type: lesson
status: active
title: "A docker:// digest without its tag is bumped to latest"
created: "2026-11-16"
---

# A docker:// digest without its tag is bumped to latest

## Context

`pr-agent.yml` ran PR-Agent as `docker://pragent/pr-agent@sha256:80edef7…  # v0.48.0`.
The digest was the `0.48.0-github_action` image. The comment said `v0.48.0`.

## Problem

Renovate does not read the comment. A reference with a digest and no tag
tracks `latest`, so #129 moved all three review steps to `latest`'s digest,
labelled with the same `v0.48.0`. `latest` is the CLI image: its entrypoint
is `python pr_agent/cli.py`, not `/entrypoint.sh`. With no arguments it
prints help and exits, and the review steps would have finished without
publishing anything. The bump looked like a routine digest refresh.
CodeRabbit flagged it, and `docker buildx imagetools inspect` on both digests
confirmed it.

## Solution

- Write the tag beside the digest:
  `docker://pragent/pr-agent:0.48.0-github_action@sha256:80edef7…`. Docker
  pulls by the digest. Renovate follows the tag's own line, including its
  `-github_action` suffix.
- `tests/pr-agent-shape.bats` requires that form on every PR-Agent step.
- When a digest bump keeps its version label, compare what the image runs
  (`Entrypoint`, `Cmd`) before merging. A label can stay the same while the
  image under it changes.
