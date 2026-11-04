# CI baseline, November 2026

A read-only audit of CI across the `mlorentedev` repositories: 24 non-archived repositories on GitHub and the
personal repositories on the self-hosted Gitea forge. The window covers pull requests and workflow runs
created from 2026-10-05 to 2026-11-04. Data came from the REST APIs only. The decisions it led to are in
[ADR-001](../adr/adr-001-one-ci-standard-for-every-forge.md).

Labels: **M** measured, **D** declared in infrastructure code, **I** inferred.

## Where pull request time goes (M)

Sample: 84 merged pull requests opened by people, 321.6 hours from open to merge in total.

| segment | share |
|---|---|
| iteration before the final push (earlier CI runs, review, author time) | 55.7% |
| green, waiting to be merged | 26.6% |
| draft | 12.5% |
| **CI on the final commit** | **5.9%** |

The shares add up to 100.7% because the segments overlap slightly. The last push is approximated by the
earliest check start on the final commit, so a little time lands in two segments. Each share is computed
against the 321.6 h total.

- Bot pull requests are the slowest class: Dependabot p50 21–42 h, release-please up to 226 h.
- 4 of the 5 open Dependabot pull requests had a failing check that nobody was acting on.
- `review-attestation` often fails several times before it passes.

A faster CI matters most through the iteration segment: every push waits for the full suite.

## Where job-minutes go (M, estimates per month)

| # | repository / workflow / job | p50 | est. min/month | cause |
|---|---|---|---|---|
| 1 | kubelab / ci / Tests | 28.6 min | 38,760 (~40% of all) | one serial pytest process over 538 test files |
| 2 | dotfiles / ci / test-windows | 5.1 min | 9,199 | Windows on every pull request |
| 3 | dotfiles / cli / test (windows) | 4.3 min | 8,035 | Windows on every pull request |
| 4 | dotfiles / ci / integration | 4.1 min | 6,693 | container built without a layer cache (3.4 min) |
| 5 | dotfiles / from-zero / macos | 10.7 min | ~5,300 (I) | full OS matrix |
| 6 | dotfiles / ci / test-macos | 3.1 min | 5,081 | macOS on every pull request |
| 12 | dotfiles / cli / cli-lint | 89 s | 1,750 | `skip-cache: true` |
| 14 | ts-bridge / ci / security | 3.9 min | 1,603 | gosec without a cache |

## Queueing (M, I)

- **GitHub.** The run-level queue is about 0 s. Jobs, however, wait for a runner: p50 451 s in hive, 80 s in
  dotfiles and 72 s in kubelab, against 2 s in quiet repositories. kubelab and dotfiles each start about ten
  workflows per pull request. Many do 5–10 s of work and hold a slot each (I: the account's concurrent-job
  limit). For example, knowledge-gate takes 96 s of wall time for 7 s of work.
- **Gitea.** One runner with capacity 2, on a 4-core node shared with the forge.
  - 97% of queued job-minutes fell while both slots were busy.
  - The busiest repository's CI takes 25.5 min p50 for a 13 min critical path. Jobs that run for seconds
    wait 23–29 min.
  - A daily `docker image prune -af` leaves the first build of the day cold. One base image re-downloads in
    about 29 min.
  - Some caches never warm: setup-python, the uv binary, the trivy database.

## Duplication (M)

| family | copies | variants | note |
|---|---|---|---|
| bitacora-status | 20 | 7+ | 18 copies carry both bugs fixed in kubelab#1504 and dotfiles#2878 |
| add-to-project | 20 | 10+ | 8 copies pinned by tag; the Dependabot skip is written 4 ways |
| pr-agent | 14 | 12 | one consumer of the shared workflow (hive), running next to its own copy |
| repo-hygiene | 12 | 5 | the drift is in vendored scripts: `check-lessons.sh` exists in 4 versions |
| release | 10 | 10 | four different names for the release token secret |
| Go / Python / Node CI | 5 / 7 / 5 | | Poetry is installed 3 different ways |

## Static findings (M)

- 49 of 84 push or pull request workflows have no path filter. A docs-only pull request runs full CI in 9
  repositories.
- 46 workflows have no `cancel-in-progress`.
- 109 of 193 jobs have no `timeout-minutes`, so they inherit 360 min. One Gitea job hung for 1,675 min.
- 29 setup-python jobs have no cache. Toolchains are installed on every run: Poetry (~2.2k min/month),
  setup-go off Linux, golangci-lint, bats, Playwright.
- 22 action references are pinned by tag, and 88 of 138 checkouts persist credentials.
- Broken and nobody noticed:
  - a CI workflow filtered on `main` in a `master` repository, which has never run;
  - a release workflow that failed 16 of 16 runs;
  - a Pages deploy that failed 5 of 5;
  - a scheduled workflow disabled for inactivity after months of failures;
  - three workflows registered as active but deleted from the tree.
- Two default branches are unprotected, and one is protected with no required checks.
- A self-hosted GitHub runner is declared in infrastructure code (D), but none is registered (M).

## The standard

The decisions are in ADR-001. The practices that follow from them, each checked by `dotf lint`:

| # | practice | where it lives |
|---|---|---|
| S1 | one required check per repository, `gate`, aggregating the jobs behind it | composite `gate` |
| S2 | pull requests run what they touch; the default branch and a nightly run everything; the skip logic is tested | composite `changes` + `dotf` |
| S3 | the OS matrix runs on pull requests only when OS-sensitive paths change | per repository, with S2 |
| S4 | test suites run in parallel (pytest-xdist, shards by duration) | per repository |
| S5 | caches are required: toolchains keyed by pinned version, buildx `type=gha`, browsers, linters | composites `setup-*`, reusable `docker-build` |
| S6 | cheap checks run as steps of one job, not as one workflow each | reusable `pr-checks` |
| S7 | every pull request workflow cancels superseded runs | caller |
| S8 | every job has `timeout-minutes` | blocks + caller |
| S9 | actions pinned by SHA, `persist-credentials: false`, least-privilege permissions, no `secrets: inherit` | everywhere |
| S10 | bot pull requests get their own lane; a red Dependabot pull request opens an issue | reusable `bot-lane` |
| S11 | CI feedback time and runner wait are reported against objectives | `dotf ci stats` + scheduled reusable |
| S12 | the pre-push hook runs the same commands as CI, scoped to the diff | `dotf` |
| S13 | no workflow stays permanently red, disabled or orphaned | `dotf lint` + S11 |

## Catalog and adoption

| block | kind | forges | status |
|---|---|---|---|
| `pr-agent` | reusable | GitHub | v0.2.0 merged; 1 consumer (hive) |
| `push-gate` | composite | GitHub | released in v0.1.0 |
| `gate`, `changes` | composite | GitHub, Gitea | planned (#9) |
| `setup-python-uv`, `setup-python-poetry`, `setup-go-lint`, `setup-node` | composite | GitHub, Gitea | planned (#10) |
| `docker-build` | reusable | GitHub | planned (#11) |
| `pr-checks` | reusable | GitHub | planned (#12) |
| `bot-lane` | reusable | GitHub | planned (#13) |
| `release` | reusable | GitHub | planned (#15) |
| `ci-stats` | reusable | GitHub | planned (#14) |

Per-repository adoption will be reported by `dotf lint` once its fleet rules exist. This table is updated with
each release.

## Method and gaps

- REST only, about 1,400 calls, GET only. Workflow run counts are capped at 2,500 by the API, so the busiest
  workflows are lower bounds.
- Job and step durations come from up to 8 recent successful runs per workflow, so failed and cancelled runs
  are not costed. Cache hits are inferred from durations, except on Gitea, where job logs were read.
- The "iteration" segment cannot be split further with REST: the API does not separate earlier CI runs,
  review waits and author time.
