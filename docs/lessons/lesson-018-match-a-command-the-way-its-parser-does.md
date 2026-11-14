---
id: "lesson-018-match-a-command-the-way-its-parser-does"
type: lesson
status: active
title: "Match a chat command the way the tool that runs it parses it"
created: "2026-11-12"
---

# Match a chat command the way the tool that runs it parses it

## Context

The review caller's concurrency key decides which PR comments share the review
group, so a newer review cancels an older one. The shared job decides which
comments it expects to publish a review. Both test the comment body for
`/review`. PR-Agent then parses the same body itself and decides what to run.

## Problem

The two checks and PR-Agent disagreed on what a review command looks like.
The key took `/review` alone or followed by a space. PR-Agent splits the
command on any whitespace, lowercases it, and runs its reviewer for `/review`,
`/review_pr`, `/auto_review` and `/answer`. So `/review` followed by a newline,
or by the CRLF a browser sends, ran a review in a group of its own: two reviews
of one PR, each holding a model slot. The shared job's
`contains(body, '/review')` was wrong the other way: it expected a review after
`/reviewed`, and after any comment that mentions `/review` later in the text.
Each check had looked right when read alone. The gap only showed when compared
with PR-Agent's parser (`command2class` and `action.lower()` in
`pr_agent/agent/pr_agent.py`).

## Solution

- Read the command set and the tokenizer from the tool's source at the pinned
  ref, and write it down as one list. Do not derive it from examples.
- Where a step can run, decide in shell, which handles every delimiter. The
  shared job's `command` step takes the first whitespace-delimited word,
  lowercases it, and matches the four commands. The publish gates then read
  its output.
- Where only an expression can run (a concurrency key is evaluated before any
  step), enumerate the cases: `startsWith(format('{0} ', body), '/cmd ')` covers
  the end of the body and a space, and
  `startsWith(body, format('/cmd{0}', fromJSON('"\n"')))` covers each other
  delimiter. GitHub expressions have no escapes, so `fromJSON` is how to get
  a newline. They compare case-insensitively, which covers the lowercasing.
- Make a test compare the lists in the key and in the step, and make it run
  the step's script on real bodies (`/review\r\n…`, `/reviewed`, `/Review`).
  A pattern test alone cannot tell which body a pattern accepts.
