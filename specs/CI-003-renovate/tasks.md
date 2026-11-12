---
tags: [spec, tasks, templates]
created: "2026-11-05"
id: "CI-003-renovate"
type: spec-tasks
status: active
owner: manu
---

# Tasks - CI-003-renovate

> TDD order. One task = one focused commit. Tick as you go. Reorder freely while spec is in `draft` state; freeze once you start `implementing`.
>
> **Inline markers** (optional, additive — borrowed from `github/spec-kit`, adapt-not-adopt per #141):
> - `[P]` — this task has **no dependency on another unchecked task**, so it is safe to run in parallel (fan out to a `Workflow`, or just batch). TDD chains (test → implement → refactor of the *same* behavior) are sequential and must NOT carry `[P]`; independent behaviors can.
> - `[AC<n>]` — this task helps satisfy **acceptance criterion #`<n>`** from `proposal.md`. Lets `/spec check` map coverage deterministically; omit it and the check falls back to semantic judgment.

## Setup

- [x] Branch created from main: `feat/renovate`
- [x] `proposal.md` is complete and acceptance criteria are testable
- [x] The owner has decided the token (`RENOVATE_TOKEN` scope) and created it (dotfiles#3202)

## Implementation

PR 1 (this repository):

- [x] [P] [AC1] Failing check: `renovate-config-validator` over `renovate/*.json` in `lint`
- [x] [AC1] `renovate/default.json` from kubelab's generic settings, `renovate/engine.json` at kubelab's pin
- [x] [P] [AC2] Failing fixture: `tests/fixtures/renovate-shape-bad.yml` breaks each rule in `tests/renovate-shape.bats`
- [x] [AC2] [AC3] `.github/workflows/renovate.yml`: weekly and on dispatch, autodiscover `mlorentedev/*`, engine from `renovate/engine.json`
- [x] [AC4] This repository's `renovate.json`: extends the preset, plus the manager for `renovate/engine.json`
- [x] [AC7] ADR-001 §6 amended; README documents the preset, the engine pin and the token

After release (owner tags):

- [ ] [AC3] Dispatch `renovate.yml`; the dashboards of this repository and kubelab update
- [ ] [AC4] The engine PR appears when the pin is behind; the preset-pin manager is verified
- [ ] Send the preset path, the engine-file path and the tag to the IDP-036 session

PR 2 (kubelab, owner merges):

- [x] [AC5] Delete `renovate.yml`, `ci.renovate.image` and `tests/test_renovate_engine_version.py`; `renovate.json` extends the preset (kubelab#3271)

Fleet adoption, in batches of four:

- [ ] [AC6] Per repository: add `renovate.json`, remove `dependabot.yml`; one line per repository here as it lands. Partial: eight adopted; kubelab keeps `dependabot.yml` and dotfiles is out of the wave, both against AC6 as written, so it stays open until the owner amends AC6 or they adopt. Fourteen non-archived repositories carry no `renovate.json` yet (2026-11-12): boilerplates, cloud-architecture-coursework, dotfiles, embedded-systems-coursework, emva1288-sensor-characterization, iris, kasa-provisioner, mail2markdown, mlorentedev, nan-video-pipeline, pdf-modifier, svqtriana.github.io, telecom-engineering, vicon-fpga-face-detection
  - kubelab: kubelab#3271 (b78d171, 2026-11-11). Renovate keeps `enabledManagers: ["custom.regex", "ansible-galaxy"]`, and Dependabot keeps the ecosystems it covered, so `dependabot.yml` stays.
  - web: web#643 (41ef534, 2026-11-11)
  - ts-bridge: ts-bridge#718 (5f76145, 2026-11-12)
  - garsync: garsync#158 (be3b180, 2026-11-12)
  - leaving-denver: leaving-denver#277 (5f2ee03, 2026-11-12)
  - pollex: pollex#127 (41c242b, 2026-11-12)
  - hive: hive#571 (23fd60e, 2026-11-12)
  - yt-metrics-cli: yt-metrics-cli#114 (fdee012, 2026-11-12)
  - dotfiles: out of this wave (dotfiles#3313)
  - All eight pinned to v0.6.0 on 2026-11-12, before the first scheduled run: garsync#161, leaving-denver#278, hive#577, pollex#128, ts-bridge#727, kubelab#3315, web#651, yt-metrics-cli#118 (#73)

## Verification

See `verification.md`.
