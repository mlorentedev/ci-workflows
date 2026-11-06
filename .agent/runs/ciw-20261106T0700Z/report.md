# Run ciw-20261106T0700Z

- Armed: 2026-11-06T07:00Z, envelope 44341b9. Ended: 2026-11-06T08:15Z.
- End reason: `goal-blocked`. Every remaining item waits on the owner: the v0.4.0 tag (release PR #23)
  or a decision on #31.

## Done

| Item | Result |
|---|---|
| Renovate dispatch, ci-workflows | Run 42181838772 `done`; Dependency Dashboard #44. Two earlier runs (42177995767, 42178889438) aborted on the account's GraphQL rate limit and finished green. |
| CI-003 evidence | #45 merged as 7991c31: AC3 for this repository, AC4 half (engine bump detected, PR waits for Monday's window), lesson-006. Merged unreviewed: CodeRabbit quota, no PR-Agent here. |
| #31 hygiene | Spec CI-005 proposed in draft #40. Parked on the issue with options A/B: `dotf lessons fmt --check` fails every adopter (hive 121 files, kubelab 730; all commit `_index.md`), and the SHA-pin rule is not in `dotf lint` yet (dotfiles#3147). |
| Debt filed | #43: the job stays green when Renovate aborts on the rate limit; consider a GitHub App token with its own pool. |

## Deviations from the envelope

- Item 1 ran before the tag and on ci-workflows alone. Its config extends the preset locally, so it needs no
  tag. kubelab's dispatch was held: its `renovate.json` is still the full old config and its own
  `renovate.yml` still runs, so a central run would prove nothing for AC5.
- #31 Blocked on the board failed: `gh project item-edit` returned `unknown owner type`. The park comment is on
  the issue.
- During the lessons measurement this run detached HEAD in `~/Projects/hive` and `~/Projects/kubelab`; both were
  put back on `master` minutes later, with no other change.

## Waiting on the owner

1. Merge #23 (v0.4.0). Then: the kubelab PR, the kubelab dispatch, and the adoption PRs.
2. Choose A or B on #31.

## Notes for the kubelab PR

- kubelab sets `enabledManagers: ["custom.regex", "ansible-galaxy"]`. Extending the preset turns on every
  other manager unless kubelab keeps that list, and it still has a `dependabot.yml`. Decide which side owns
  github-actions there.
- `ci.renovate.image` in `infra/config/values/common.yaml` is the engine pin the IDP-036 Gitea run reads.
  Removing it is a change for the IDP-036 session to agree to.
- `renovate-derived.yml` and four `tests/test_renovate_*.py` files also exist; only
  `test_renovate_engine_version.py` is in CI-003's list.

## Fleet inventory (2026-11-06)

`dependabot.yml` without `renovate.json`: dotfiles, garsync, hive, leaving-denver, pollex, ts-bridge, web,
yt-metrics-cli (8). kubelab has both. Two batches of 4.
