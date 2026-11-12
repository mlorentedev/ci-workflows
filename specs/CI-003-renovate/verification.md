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
- [x] AC5 -> kubelab#3271 (b78d171): kubelab's `renovate.yml` and `tests/test_renovate_engine_version.py` are gone from
      master, `ci.renovate.image` survives only in the text of its IDP-036 spec, and its `renovate.json` extends the preset.
- [ ] AC6 -> partial. Eight repositories carry a `renovate.json` extending `renovate/default#v0.6.0`, read from each default
      branch on 2026-11-12; per repository in tasks.md. Seven have no `dependabot.yml`; kubelab keeps its own by design.
      dotfiles is out of the wave (dotfiles#3313). Both contradict AC6 as written, so it stays open until the
      owner amends it or they adopt. Fourteen non-archived repositories carry no `renovate.json` yet; tasks.md
      lists them.
- [x] AC7 -> ADR-001 decision 6 amended; README `## renovate`.

## Secret exposure inventory (#74)

A Renovate pull request is a same-repository run: it reads the repository's Actions secrets and whatever
`GITHUB_TOKEN` scope the workflow grants. A Dependabot run reads neither. Each adopter's `pull_request` jobs,
read from its default branch on 2026-11-12, are listed below by whether they run dependency code (install,
build or test) while holding a secret or a write-scoped token. The `review` job that every adopter calls holds
the model keys, but it runs the pinned PR-Agent image over the diff, not the repository's code. The
`add-to-project` job holds `BITACORA_PAT` but checks nothing out. Neither job is counted below.

- garsync (a15f62a): none. The `ci.yml` and `docs.yml` build jobs read no secret, and the workflows pin
  `contents: read` over the repository's default of `write`.
- leaving-denver (a17a1f3): none. `ci.yml` `deploy` holds the Cloudflare token and the sealed seller data, but
  only runs when `github.ref == 'refs/heads/main'`.
- hive (270d9ff): none. The CI jobs read no secret; the default token is read-only.
- pollex (73d5128): none, for the same reasons.
- ts-bridge (46b921c): none, for the same reasons.
- kubelab (3e8adfd): **exposed**, tracked in kubelab#3344.
  - `ci.yml` grants `contents`, `pull-requests` and `security-events: write` at workflow level, so `validate`,
    `tests` and `test-shards` run dependency code with a write token that `actions/checkout` persists.
  - `call-publish` skips only `dependabot[bot]`, so a Renovate branch that changes an app pushes a `sha-` image
    to Docker Hub.
  - Renovate there runs only `custom.regex` and `ansible-galaxy`, which narrows what such a branch can change.
- web (b92fd06): none. `pr-validation.yml` `validate` passes the Docker Hub credentials to `build-image.yml`
  with `push: false`. The login step is skipped and BuildKit build steps cannot read the `secrets` context.
- yt-metrics-cli (1be1804): none. The CI jobs read no secret; the default token is read-only.

Mitigations already in force everywhere: the preset's `minimumReleaseAge` of 3 days (npm, PyPI, Go) and the
uv adopters' `exclude-newer` (#81). #74's third criterion no longer needs a decision: every adopter already pins
v0.6.0, which carries the release age.

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
