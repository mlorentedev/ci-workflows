---
id: "lesson-008-a-bare-negation-in-bats-checks-nothing-unless-it-is-last"
type: lesson
status: active
title: "A bare negation in bats checks nothing unless it is last"
created: "2026-11-10"
---

# A bare negation in bats checks nothing unless it is last

## Context

This repository's bats tests check each rule twice: the rule passes on the real
file and fails on a copy that breaks it, written `! rule "$broken"`.

## Problem

Bash exempts a command negated with `!` from errexit. In a test body, a bare
`! rule "$broken"` therefore fails the test only when it is the last line, where
it sets the function's return status. In `tests/specs.bats` (#52) the negatives
were followed by a positive check, so they never ran as assertions: a rule that
accepted everything still passed. The review did not catch it; mutating the rule
did.

## Solution

- In a test body, write a negative check as `run ! cmd`, under
  `bats_require_minimum_version 1.5.0`. Helpers keep `!` as their return value.
- `tests/bats-style.bats` fails on a bare `!` inside a `@test` body (#56).
- Prove a negative check by making the rule permissive and watching it go red.
