# Run ciw-20261106T0650Z — disarm report

**run ciw-20261106T0650Z — ended budget-items after 2 iterations / about 1.25h — 1 done, 0 parked, 0 merged, 1 unmerged.**
Waiting on a human: one PR to merge. Nothing irreversible was landed or published: no merge, no tag, no release.

## Waiting on you

1. **mlorentedev/ci-workflows#42** — `feat(setup-node): add a cached Node toolchain composite` (refs #10, CI-004 PR 1). Head `27f7a90`. CI is green and the triage is posted. It touches `.github/workflows/lint.yml`, so it is your merge (`merge: never`).
   - The fix commit `27f7a90` has **no bot review**: CodeRabbit was rate-limited on it. CodeRabbit reviewed `0a3921c`, and the triage comment disposes all 8 findings: 6 applied (one of them in part), 2 declined with reasons.
   - After merge, the push on `main` warms the npm cache. The next PR touching `toolchains` should log `cache-hit=true`. Record both runs in `specs/CI-004-toolchain-setup/verification.md` (AC3).

## Parked

None.

## Done but unmerged

- #42, above.
- Filed #46, debt found while working: nothing in CI parses `specs/*/features.json`. #42 guards only CI-004's file.

## Evidence index

| Item | Command | Exit | Output |
|---|---|---|---|
| Suite at `27f7a90` | `bats tests/` | 0 | 125 ok, 0 not ok (local) |
| Lint at `27f7a90` | `actionlint` | 0 | clean |
| CI at `27f7a90` | check runs on the head SHA | — | gate, lint, test, renovate-config, smoke-setup-node, changes: success. CodeRabbit: neutral (rate limited). |
| Smoke cache line | `gh run view 42180020556 --job 127776428277 --log` | 0 | `cache-hit=false`, `cache-primary-key=node-cache-Linux-x64-npm-806b948…` |
| Feature-list guard | `jq -e` over the old `features.json` | 5 | parse error, so the guard fails on the defect it covers |
| Triage queue | `dotf pr triage-queue` | 0 | `[OK] no reviewer output is awaiting a disposition` |
| Pins | `gh api repos/actions/{setup-node,cache}/tags` | 0 | v7.1.0 = `949feb2…`, v6.1.0 = `55cc834…` |

## Budget spent

2 of 5 iterations, about 1.25h of 8h, 1 of 1 items. No dollar figure exists: the provider exposes none.

## Host suspend

Covered while the run was working. `caffeinate -i -s -t 28800` (PID 55393) held from arming. The run ended at about 08:05Z, well inside the window. The machine was awake throughout.

## Notes

- The advisor was rate-limited at arming. No decision in this run needed it: the plan had been settled with the owner, and the review dispositions are tied to evidence.
- Peer coordination: session `feat-issue-15-release-please-21` runs #32 (pages, now CI-006) with no path overlap. README.md is shared; whoever merges second rebases. `feat/issue-31-hygiene` (#31, CI-005) belongs to neither of us.
- A slip during the run: a `git checkout` of `lint.yml` threw away work that was not yet committed. A backup made just before restored it, verified by the diff stat and a green suite. In future, mutation checks run on a copy, never on the tracked file.

## Next action

Review and merge #42. Then record the warm run and the hit in `verification.md` and run the imagesensortool pilot (AC4).
