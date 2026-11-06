---
tags: [spec, verification]
created: "2026-11-05"
id: "CI-005-pages"
type: spec-verification
status: active
owner: manu
---

# Verification - CI-005-pages

## Evidence

- [x] Criterion 1. `pages-shape.bats`: trigger, defaults, no secret, no branch, no caller-owned keys, jobs, pins. Each rule also runs against `fixtures/pages-shape-bad.yml`, which must fail it.
- [x] Criterion 2. `pages-shape.bats`: build reads only, deploy asks for pages and id-token, timeouts, credentials, pull request skips upload and deploy, optional check, inputs through env, `page_url`.
- [x] Criterion 3. `pages-callers.bats`, 5 tests over `fixtures/pages-callers/{hive,ts-bridge}.yml`, each rule failing on `fixtures/pages-caller-shape-bad.yml`.
- [x] Criterion 4. README `## pages`.
- [ ] Criterion 5. After release: the first consumer's migration PR and its deploy run.

## Test status

- `bats tests/` reports 0 not ok. `actionlint` reports no findings.
- The pinned SHAs resolve to their tags: checkout v7.0.1, setup-node v7.1.0, upload-pages-artifact v5.0.0, deploy-pages v5.0.1 (`git ls-remote`).

## Decisions made during implementation

- **Build and check commands run through `bash -c "$VAR"`.** The inputs reach the script through `env`, never by `${{ }}` interpolation into `run:`, so a caller's command cannot inject YAML-expanded text. A test holds it.
- **Pull requests build.** Only hive does this today, and it costs nothing for a caller whose triggers omit `pull_request`.
- **`environment: github-pages` lives in the reusable job.** It is mechanism (deployment record and protection rules), like the review lane in `pr-agent.yml`.
- **No Gitea path.** GitHub Pages only (ADR-001 §2); no consumer deploys pages from Gitea.

## Promotion candidates

- [ ] Lesson for the repo's `docs/lessons/`? <answer at archive>
- [ ] ADR-worthy decision for the repo's `docs/adr/adr-XXX.md`? <answer at archive>
- [ ] New pattern candidate for `00_meta/patterns/`? <answer at archive>
