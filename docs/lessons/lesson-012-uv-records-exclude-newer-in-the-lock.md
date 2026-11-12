---
id: "lesson-012-uv-records-exclude-newer-in-the-lock"
type: lesson
status: active
title: "uv records exclude-newer in the lock, so set it in pyproject.toml"
created: "2026-11-12"
---

# uv records exclude-newer in the lock, so set it in pyproject.toml

## Context

The Renovate preset waits three days on new PyPI releases, but its weekly uv
lock refresh runs `uv lock --upgrade` with no cutoff (engine 44.199.2,
`pep621/processors/uv.js`), so the refresh can pull a release published minutes
earlier into a CI run with the repository's secrets (#81).

## Problem

The obvious fix is `UV_EXCLUDE_NEWER="3 days"` in the Renovate runner's
environment. uv 0.12 accepts the relative form, but it writes the cutoff into
the lock's options (`exclude-newer-span = "P3D"`). A lock written that way fails
`uv sync --locked` and `uv lock --check` in any shell without the variable,
which is the adopter's own CI, and a developer's plain `uv lock` removes it
again. The fix would have broken the pull request it produced.

## Solution

- Put the cutoff in the project: `[tool.uv] exclude-newer = "3 days"` in
  `pyproject.toml`. Renovate, CI and a developer's machine then read the same
  setting, and `uv lock --check` passes.
- Before moving a setting into a runner's environment, check whether the tool
  records it in a committed file. If it does, the setting belongs in the
  project's config, not in one caller's environment.
- Test it with the repository's own lock gate (`uv lock --check`,
  `uv sync --locked`), not only with the command that writes the lock.
