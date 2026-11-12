---
id: "lesson-013-a-model-capacity-is-not-a-prompt-budget"
type: lesson
status: active
title: "A model's capacity is not a prompt budget, so PR-Agent needs both"
created: "2026-11-12"
---

# A model's capacity is not a prompt budget, so PR-Agent needs both

## Context

The shared PR-Agent workflow runs NaN models PR-Agent has no built-in entry
for, so it sets `CONFIG__CUSTOM_MODEL_MAX_TOKENS` to the model's context
window. A large diff on svqtriana.github.io then went to every model in the
chain whole, each call ran to its timeout, and the step was killed at its
twelve-minute bound before the fallbacks finished (run 42562380120, #88).

## Problem

PR-Agent (v0.48.0) reads two settings that sound alike. `custom_model_max_tokens`
says what the model accepts; `max_model_tokens` is the budget PR-Agent clips the
diff to before it sends it. With only the first set, the budget is the whole
window, so nothing is clipped. The callers that had worked set
`max_model_tokens` and `ai_timeout` in their own `.pr_agent.toml`, which hid
the gap until a caller without them got a large diff. The step bound was also
fixed by hand, with no check that a full fallback chain at the call timeout fits
inside it (#87).

## Solution

- Set the capacity and the budget together, with the budget well below the
  capacity: `CONFIG__MAX_MODEL_TOKENS: "32000"` next to the 200000 capacity,
  and `CONFIG__AI_TIMEOUT: "300"`, in the shared step, where they override any
  caller's toml.
- Derive the step bound from the chain: the longest chain a caller may declare
  (three models) times the call timeout, plus the image start. 3 x 300 s +
  120 s is 17 minutes. That holds only with one attempt per model, so the
  step also pins `CONFIG__NUM_RETRIES: "0"` and keeps
  `CONFIG__RETRY_SAME_MODEL_ON_TIMEOUT: "false"`; a caller's `num_retries`
  would otherwise multiply every timeout.
- Keep the arithmetic in a test (`tests/pr-agent-budget.bats`) that reads the
  numbers from the workflow, so raising a timeout without the bound fails CI.
- When a tool takes a size setting for a model, check whether it also takes a
  budget; a capacity alone is a ceiling nothing enforces below.
