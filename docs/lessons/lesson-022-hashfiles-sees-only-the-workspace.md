---
id: "lesson-022-hashfiles-sees-only-the-workspace"
type: lesson
status: active
title: "hashFiles() sees only the workspace, so a guard on a runner.temp file is always false"
created: "2026-11-17"
---

# hashFiles() sees only the workspace, so a guard on a runner.temp file is always false

## Context

`docker-publish.yml` v0.8.0 wrote each platform's Trivy report to `${{ runner.temp }}/trivy.sarif`. It uploaded the report only `if: hashFiles(format('{0}/trivy.sarif', runner.temp)) != ''`. The shape tests asserted the upload's category and its `continue-on-error`, and they passed.

## Problem

`hashFiles()` matches files under `GITHUB_WORKSPACE` only. An absolute path outside it matches nothing, so the guard was `''` on every run. The upload was skipped, the job stayed green, and no release scan reached the Security tab. web's first master run on v0.8.0 shows it: in both `scan` jobs the report step succeeded and `upload-sarif` was skipped (mlorentedev/web run 44028958786, #136).

A shape test cannot see this, because the YAML is well formed and the guard reads sensibly. CI-010 had no runner run that looked at whether the upload step executed, only at whether the job passed.

## Solution

Write the report in the workspace (`output: trivy.sarif`), and guard and upload that same relative path. The scan job checks nothing out, so no committed file can stand in for the report. `tests/docker-publish-shape.bats` now requires the report path to be relative and free of `runner.temp` and `..`. It also requires the guard to be `hashFiles('<that path>')`, and the scan job to have no checkout.

Rule: a step guarded by `hashFiles()` must name a path inside the workspace. When a step is optional (`if:` plus `continue-on-error`), a green job proves nothing about it. Verify it on a runner by the step's own conclusion, and here by the analysis it produces.
