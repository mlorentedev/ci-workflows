---
id: "lesson-010-a-carriage-return-in-ifs-splits-differently-across-bash-versions"
type: lesson
status: active
title: "A carriage return in IFS splits differently across bash versions"
created: "2026-11-11"
---

# A carriage return in IFS splits differently across bash versions

## Context

`setup-python-uv` reads the first line of `.python-version` with `read -r`.
A file written with CRLF endings left `3.13\r` in the value (#67).

## Problem

The first fix was `IFS=$' \t\r' read -r python`. For `read`, `\r` is not IFS
whitespace but an IFS delimiter, and how a trailing delimiter is dropped from
the last variable is not the same in every bash. The test passed locally under
bash 3.2 and 5.3 and failed in CI under the runner's bash 5.2, ubuntu-24.04's (#69, run
42982492985).

## Solution

- Read the line plainly, then strip what is unwanted with parameter expansion,
  which every bash treats alike:
  `python="${python//$'\r'/}"`, then
  `python="${python%"${python##*[![:space:]]}"}"` for the trailing space.
- Do not lean on non-whitespace IFS characters to trim.
- A shell test that passes locally has run on the local bash only. CI's bash is
  the one that counts for a composite.
