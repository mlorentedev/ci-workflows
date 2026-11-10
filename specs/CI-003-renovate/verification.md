---
tags: [spec, verification, templates]
created: "2026-11-05"
id: "CI-003-renovate"
type: spec-verification
status: active
owner: manu
---

# Verification - CI-003-renovate

## Evidence

- [x] AC1 -> `lint / renovate-config` runs the engine's `renovate-config-validator --strict --no-global` over
      `renovate.json` and `renovate/default.json`; locally it validated both and rejected a config with a
      packageRule lacking a selector. Tests 7-9 of `tests/renovate-shape.bats` pin the engine file and the
      preset (no GitHub-only option, no automerge). The tag waits for the release PR.
- [x] AC2 -> `tests/renovate-shape.bats` tests 1-6, each run against the workflow and against
      `tests/fixtures/renovate-shape-bad.yml`.
- [ ] AC3 -> this repository done, kubelab pending. Dispatch run 42181838772 (2026-11-06, `repositories=mlorentedev/ci-workflows`)
      finished with `"result": "done"` and opened the Dependency Dashboard, #44. It lists every pinned workflow
      and composite, including `dorny/paths-filter` in `.github/actions/changes/action.yml`. Two earlier runs
      (42177995767, 42178889438) aborted on the account's GraphQL rate limit and still finished green
      (lesson-006, #43). kubelab is dispatched after its PR, so the run reads the preset, not its old config.
- [ ] AC4 -> half done. The `renovate/engine.json` manager works: #44 lists `ghcr.io/renovatebot/renovate 44.199.2
      -> 44.221.4` under Awaiting Schedule, grouped in `renovate/minor-and-patch-updates`. The PR itself opens in
      the preset's window. The first scheduled run (42582312694, 2026-11-09) started 6.5 hours late, after the Monday 00:00-06:59 window had closed, and opened nothing; #48 widened the window to all of Monday. The preset-tag manager waits for the first tag.
- [ ] AC5 -> the kubelab PR.
- [ ] AC6 -> fleet adoption, per repository in tasks.md.
- [x] AC7 -> ADR-001 decision 6 amended; README `## renovate`.

## Test status

- `bats tests/`: 97 tests, 0 failures.
- `actionlint`: clean.

## Decisions made during implementation

- No reusable workflow. With one central autodiscover run it would have a single caller, and a caller in
  another repository could not read `renovate/engine.json` at the reusable workflow's ref.
- Action bumps commit as `ci(deps):`, so they do not cut a fix release through release-please. Every other
  update keeps kubelab's `fix(deps):`.

## Promotion candidates

Answer each line `yes: <path>`, naming the file you promoted, or `no: <reason>`. `dotf spec archive` refuses a line left unanswered, a `no` without a reason, and a `yes` whose file does not exist; a `00_meta/` path is looked up in the vault.

- [ ] Lesson for the repo's `docs/lessons/`? <yes: path / no: reason>
- [ ] ADR-worthy decision for the repo's `docs/adr/adr-XXX.md`? <yes: path / no: reason>
- [ ] New pattern candidate for `00_meta/patterns/`? Only if this recurs in >1 project. <yes: path / no: reason>

## Archive checklist

- [ ] `proposal.md` frontmatter set to `status: archived`
- [ ] Folder moved: `specs/CI-003-renovate/` -> `specs/archive/CI-003-renovate/`
- [ ] Bitácora board ticket for this spec moved to Done / closed with PR link (ADR-018)
- [ ] Promotions above executed (if any)
