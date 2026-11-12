---
tags: [spec, verification]
created: "2026-11-05"
id: "CI-006-pages"
type: spec-verification
status: active
owner: manu
---

# Verification - CI-006-pages

## Evidence

- [x] Criterion 1. `pages-shape.bats`: trigger, defaults, no secret, no branch, no caller-owned keys, jobs, pins. Each rule also runs against `fixtures/pages-shape-bad.yml`, which must fail it.
- [x] Criterion 2. `pages-shape.bats`: build reads only, deploy asks for pages and id-token, timeouts, credentials, pull request skips upload and deploy, optional check, inputs through env, `page_url`.
- [x] Criterion 3. `pages-callers.bats`, 5 tests over `fixtures/pages-callers/{hive,ts-bridge}.yml`, each rule failing on `fixtures/pages-caller-shape-bad.yml`.
- [x] Criterion 4. README `## pages`.
- [x] Criterion 5. ts-bridge#741 calls `pages.yml@2355330` (v0.6.0) from its `pages` job. It merged as `9c9d70b` on 2026-11-12. Push run [43288112747](https://github.com/mlorentedev/ts-bridge/actions/runs/43288112747) ran `pages / build` (job 131426819277) and `pages / deploy` (job 131427043625), both success. `https://mlorentedev.github.io/ts-bridge/` answers 200 afterwards. The caller fixture `tests/fixtures/pages-callers/ts-bridge.yml` matches the merged file's `jobs:` block, except for the pin, which the fixture spells as a placeholder.

## Test status

- `bats tests/` reports 0 not ok. `actionlint` reports no findings.
- The pinned SHAs resolve to their tags: checkout v7.0.1, setup-node v7.1.0, upload-pages-artifact v5.0.0, deploy-pages v5.0.1 (`git ls-remote`).

## Decisions made during implementation

- **Build and check commands run through `bash -c "$VAR"`.** The inputs reach the script through `env`, never by `${{ }}` interpolation into `run:`, so a caller's command cannot inject YAML-expanded text. A test holds it.
- **Pull requests build.** Only hive does this today, and it costs nothing for a caller whose triggers omit `pull_request`.
- **`environment: github-pages` lives in the reusable job.** It is mechanism (deployment record and protection rules), like the review lane in `pr-agent.yml`.
- **No Gitea path.** GitHub Pages only (ADR-001 §2); no consumer deploys pages from Gitea.

## Promotion candidates

- [x] Lesson for the repo's `docs/lessons/`? no: the first consumer went in as planned; nothing failed that a lesson would prevent
- [x] ADR-worthy decision for the repo's `docs/adr/adr-XXX.md`? no: the build/deploy split and the caller-owned triggers are recorded in the proposal and the README
- [x] New pattern candidate for `00_meta/patterns/`? no: a reusable Pages workflow is one instance of the existing reusable-workflow contract (AGENTS.md rules 1-4)

## Review dispositions

The review (`review.md`) returned PASS with three Minor findings and a question.

- `features.json` f5 still pending: applied. Its `state` and `evidence` now carry the ts-bridge run; the `verification` string is unchanged, so the review's digest holds.
- A whitespace-only `check_command` runs as a no-op: declined. The input belongs to the caller, in the caller's own repository, and the empty case, which is the documented way to skip the check, is tested.
- `pins_every_action` checks the SHA and comment shape, not that the SHA is the tag: declined. The pins were checked with `git ls-remote` at review time, and any pin change is a PR a human reads.
- Issue #32 open: closed by the PR that archives this spec.
