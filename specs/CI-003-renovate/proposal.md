---
id: "CI-003-renovate"
type: spec
status: draft # draft | implementing | verifying | archived
created: "2026-11-06"
issue: "mlorentedev/ci-workflows#30"   # repo#NNN — GitHub issue / Project item that tracks this spec
tags: [spec, proposal, ci, renovate, dependencies]
template_version: "1.0"
owner: manu
---

# CI-003-renovate

## Why

<!-- from issue #30: feat: run Renovate for every repository on both forges from one preset -->

Dependency updates are set up per repository and per forge. Renovate runs only in kubelab, where generic
settings and kubelab's own managers share one `renovate.json`, and its engine pin lives in kubelab's
`common.yaml`. Nine other repositories carry a `dependabot.yml`, in nine variants. Gitea has no Dependabot, so
Gitea repositories get no updates at all. The owner decided on 2026-11-05/06 that Renovate replaces Dependabot
across the fleet on both forges, and that everything reusable lives in this repository: the preset, the
engine version and the GitHub workflow.

## What

- **A shared preset**, `renovate/default.json`. It is plain JSON with no GitHub-only options, so a Gitea run
  can extend it too. It holds the generic settings from kubelab's `renovate.json`: `config:recommended`,
  semantic commits with the `fix(deps):` prefix, timezone Europe/Madrid, a Monday schedule (widened from Monday night in #48), the
  `dependencies` and `renovate` labels, `prConcurrentLimit` 3 plus an hourly limit, minor and patch grouped
  while majors stay individual, a Dependency Dashboard, and no automerge. Repositories extend it with
  `github>mlorentedev/ci-workflows//renovate/default#<tag>`.
- **The engine pin**, `renovate/engine.json` (`{"image": ..., "version": ...}`), sits at the same tag as the
  preset. This repository's own Renovate bumps it, `renovate.yml` reads it, and the Gitea run reads
  it at the same tag.
- **One scheduled run, here** (`.github/workflows/renovate.yml`), weekly and on dispatch. It reads the
  engine pin from `renovate/engine.json`, authenticates with `RENOVATE_TOKEN`, runs
  `renovatebot/github-action` pinned by SHA, and autodiscovers `mlorentedev/*` with
  `RENOVATE_ONBOARDING=false` and `RENOVATE_REQUIRE_CONFIG=required`. So a repository is updated once it
  carries a `renovate.json`, and is ignored before that: adopting Renovate means adding that file, and no
  repository needs a caller of its own. A dispatch can name repositories. There is no reusable workflow:
  it would have one caller, and called from another repository it could not read `renovate/engine.json`.
- **This repository adopts first.** Its `renovate.json` extends the preset, and adds a manager that bumps
  `renovate/engine.json` and the preset tag that consumers pin.
- **kubelab moves over.** A kubelab PR deletes `renovate.yml`, `ci.renovate.image` and
  `tests/test_renovate_engine_version.py`. Its `renovate.json` keeps only the custom managers and package
  rules, on top of `extends` of the preset. The owner merges it.
- **Fleet adoption** follows: per repository, add `renovate.json` and remove `dependabot.yml`. The PRs go
  out in batches, like the bitácora rollout (dotfiles#3188), through `dotf fleet apply` once it exists
  (dotfiles#3148), or by hand in batches before that.

## Out of scope

- The Gitea run: a Beelink systemd timer owned by the IDP-036 session (kubelab#3130 amends its spec). This
  spec gives it the preset path, the engine-file path and a tag.
- The token permission for vulnerability alerts (kubelab#3129). The preset documents what it needs.
- Dependabot security alerts. They are a separate GitHub feature and stay on.
- Any repository's own custom managers, other than moving kubelab's as they are.

## Risks / open questions

- **The token (decided 2026-11-06).** `RENOVATE_TOKEN`, created by the owner and registered in
  dotfiles#3202. The central run needs one token for every repository. It needs contents, pull requests and
  issues (for the dashboard) write, and `workflows` write, because bumping action pins edits
  `.github/workflows`. A PR opened with `GITHUB_TOKEN` starts no checks, so a PAT is required. Proposal: a
  fine-grained PAT, `RENOVATE_TOKEN`, scoped to all repositories, registered in dotfiles' secret registry
  like `RELEASE_TOKEN`. The owner creates it. The first run proves its permissions.
- **Review fan-out.** The first run over several adopted repositories can open three PRs each. Every PR
  starts a PR-Agent review, and NaN serves five at a time. Mitigations: adopt in batches, keep
  `prHourlyLimit` low, and have bot branches (`renovate/`) skip the review or take the bot lane (#13),
  which is a branch prefix that forfeits, not one that grants.
- **Preset pin drift.** Consumers pin the preset by tag. Renovate's `renovate-config-presets` manager
  updates those pins. This must be verified on the first release, or else consumers stay on the first tag.
- **Gitea reading github> presets.** A Gitea-hosted run that extends a `github>` preset fetches it from
  github.com and needs a GitHub token for that (`GITHUB_COM_TOKEN`). The IDP-036 session owns that run.
- **kubelab's runner.** kubelab runs Renovate on `vars.RUNNER_DOCKER`. The central run uses `ubuntu-latest`,
  which needs Docker, and the hosted runner has it.

## Acceptance criteria

1. [ ] `renovate/default.json` and `renovate/engine.json` pass `renovate-config-validator`, and a tagged
      release carries both.
2. [ ] `renovate.yml` reads the engine pin from `renovate/engine.json`, fails first when
      `RENOVATE_TOKEN` is missing (naming the remedy), requires a config, never onboards, gives
      `GITHUB_TOKEN` only contents read, and pins every action by SHA. Each rule fails against a fixture
      that breaks it.
3. [ ] `renovate.yml` runs weekly and on dispatch. A dispatch updates the Dependency Dashboard of this
      repository and of kubelab.
4. [ ] This repository's Renovate opens a PR when `renovate/engine.json` is behind the latest engine.
5. [ ] After the kubelab PR merges, kubelab's dashboard and PRs come from the central run. kubelab has no
      `renovate.yml`, no `ci.renovate.image` and no engine test.
6. [ ] Every non-archived GitHub repository carries a `renovate.json` that extends the preset, and none
      carries a `dependabot.yml`. Tracked per repository in tasks.md.
7. [ ] ADR-001 §6 is amended: Renovate bumps the pins, not Dependabot.

## References

- ADR: [`docs/adr/adr-001-one-ci-standard-for-every-forge.md`](../../docs/adr/adr-001-one-ci-standard-for-every-forge.md), decisions 2, 5 and 6
- Epic: mlorentedev/ci-workflows#8; superseded: #18
- kubelab: #3110 (current Renovate), #3130 (IDP-036 amendment), #3129 (alerts permission), #3085
- Fan-out pacing: mlorentedev/dotfiles#3188, #3148
