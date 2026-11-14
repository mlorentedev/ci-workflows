---
id: "lesson-019-a-workflow-command-inside-command-substitution-is-swallowed"
type: lesson
status: active
title: "An ::error:: inside a command substitution never reaches the log"
created: "2026-11-13"
---

# An ::error:: inside a command substitution never reaches the log

## Context

The shared job's class guard (#82) reads two files from the caller's default
branch with `gh api`. A file that does not exist is fine (404). Any other
failure must fail the step with a message that says what could not be read.
The first draft had a `fetch` helper that printed the file and was called as
`toml=$(fetch .pr_agent.toml)`.

## Problem

On an API error the helper printed `::error::Could not read …` and exited 1.
Both happened inside `$(...)`. The exit status did fail the step, through the
`bash -e` that GitHub runs `run:` blocks with. But the runner reads workflow
commands from the step's stdout, and the substitution had captured that stdout
into `toml`. The step would go red with no annotation and no line saying why.
The bug cannot show in a test that only checks the exit status, and the
success path works.

## Solution

- A helper that can fail with a message writes its data to a file it is given,
  never to stdout: `fetch .pr_agent.toml "${RUNNER_TEMP}/class-guard.toml"`.
  Then the `::error::` line goes to the real stdout, and the caller reads the
  file afterwards.
- Run the step's own script in bats with the shell GitHub uses
  (`bash -e -c "$(yq '…run' workflow.yml)"`), and assert on the message
  (`grep -qF 'Could not read' <<<"${output}"`) as well as on the status.
