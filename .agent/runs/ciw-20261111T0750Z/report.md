# Run ciw-20261111T0750Z

run ciw-20261111T0750Z: ended queue-empty after 2 items, 07:43Z to 08:07Z (0h24). 2 done, 0 parked, 0 merged, 1 unmerged. Waiting on you: one PR to merge and one cross-repo decision. Nothing irreversible was done: no merge, no tag, no release.

## Waiting on you

1. **Merge ci-workflows#69** (closes #67). Head `c3da69b`, every check green, `gate` included, mergeable `clean`, triaged, and `dotf pr triage-queue --pr 69` exits 0. The fixes reach callers only at the next tag after v0.5.0.
2. **Decide a conflict in mlorentedev/dotfiles#3147.** Its rule "no linter runs with `skip-cache`" contradicts `setup-go-lint`, which sets `skip-cache: true` on purpose: dotfiles lessons 353 and 501 say a restored golangci-lint result cache reports findings a clean run does not. Options:
   - (A) The rule exempts the golangci-lint result cache and checks only that `setup-*` caches are on.
   - (B) The rule stands and `setup-go-lint` caches results, against lessons 353 and 501.

   Not acted on: it is another repository, outside this run's scope.

## Parked

None.

## Done but unmerged

- ci-workflows#69 (#67):
  - `setup-node` caches Playwright at one path on every OS and exports `PLAYWRIGHT_BROWSERS_PATH`;
  - `setup-python-uv` strips a CRLF ending from `.python-version`;
  - lesson 010.

## Done

- ci-workflows#71 filed: a macOS smoke of the toolchain composites, conditional to pass the dotfiles#3147 macOS rule. Board: Backlog.
- No fleet-adoption ticket. Epic #8 says per-repository adoption is not hand-ticketed: `dotf lint` (dotfiles#3147) finds it and `dotf fleet apply` opens it.
- Board and epic hygiene:
  - #67 added to the board as In Progress, and #71 as Backlog;
  - #10 ticked in epic #8;
  - the merged worktree `docs-issue-10-close-ci-004` removed.

## Evidence index

| Item | Command | Exit / result |
|---|---|---|
| #69 tests | `bats tests/` in `fix-issue-67-toolchain-edge-cases` | 0 not ok |
| #69 CI | lint run 42983436711 on `39b45bb`; checks on `c3da69b` | all success, `gate` success |
| #69 first head | lint run 42982492985 on `1948801` | `test` failed: CRLF case under bash 5.2, fixed in `39b45bb` |
| #69 triage | `dotf pr triage-queue --pr 69` | exit 0 |
| #69 lint | `actionlint` | clean |
| Board | GraphQL `projectItems` for #67 and #71 | In Progress, Backlog |

## Budget

- 2 of 2 items and 3 of 6 iterations, in 24 minutes of wall clock.
- No dollar figure exists for this run.

## Host

`caffeinate -i -t 43200` ran from arming. The run ended at 08:07Z, well inside the window, so no suspend could have hidden work.

## Coordination

- Peer runs in ci-workflows until 19:43Z and 19:45Z: `ci-workflows-34` and `feat-issue-15-release-please-50`. Both confirmed no overlap.
- The run id was renamed from `…0743Z` to `…0750Z` because a peer run used the same one.
- Lesson numbers are announced before pushing. This run took 010.

## Next action

Merge ci-workflows#69, then decide (A) or (B) for dotfiles#3147.
