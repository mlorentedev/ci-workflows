---
id: "lesson-006-renovate-exits-zero-when-it-aborts-on-the-rate-limit"
type: lesson
status: active
title: "Renovate exits zero when it aborts on the rate limit"
created: "2026-11-06"
---

# Renovate exits zero when it aborts on the rate limit

## Context

The first manual runs of `renovate.yml` (CI-003, #30) used `RENOVATE_TOKEN`, a
PAT of the owner's account. Several agent sessions use the same account's API
at the same time.

## Problem

Two runs finished green and did nothing. Renovate logged
`Rate limit exceeded - aborting` and `"result": "rate-limit-exceeded"` for the
repository, but `renovatebot/github-action` exited 0. The REST `rate_limit`
endpoint, probed with the same token, still reported about 2,900 of 5,000
GraphQL points left. A GraphQL query returned `graphql_rate_limit` anyway, so the
account was blocked by a limit that endpoint does not show. Half an hour
later the same dispatch finished with `"result": "done"`.

## Solution

- Judge a Renovate run by each repository's `result` in its log, never by the
  job's colour. `done` is success; `rate-limit-exceeded` means nothing happened.
- Check GraphQL with a real query, such as `{ viewer { login } }`, not with
  `GET /rate_limit`.
- #43 makes the job fail on a non-`done` result, and weighs a GitHub App token,
  whose rate pool is its own, against the shared PAT.
