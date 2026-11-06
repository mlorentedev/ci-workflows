---
tags: [spec, verification]
created: "2026-11-04"
id: "CI-002-release"
type: spec-verification
status: active
owner: manu
---

# Verification - CI-002-release

## Evidence

- [x] Criterion 1. `release-shape.bats`: the eleven workflow rules, each also run against
      `fixtures/release-shape-bad.yml`, which must fail it.
- [x] Criterion 2. `release-shape.bats` "a missing token fails first, naming the remedy".
- [x] Criterion 3. `release-shape.bats` "the manifest holds one semver…", "one root package…", "the
      changelog is release-please's own…", "only feat, fix, perf and revert open a release", "the release writes no version file"; the manifest was `0.2.0` at
      merge (`29550e9`).
- [x] Criterion 4. `release-callers.bats`, 9 tests over `fixtures/release-callers/{dotfiles,pollex}.yml`
      and `.github/workflows/release-please.yml`, each rule also failing on
      `fixtures/release-caller-shape-bad.yml`.
- [x] Criterion 5. README `## release` and "How this repository is released"; AGENTS.md.
- [x] Criterion 6. Merging #19 (`29550e9`) opened release PR #20, `chore(main): release 0.3.0`. Its `lint`
      and `test` checks ran, so the PAT starts workflows. #20 changed only the manifest and `CHANGELOG.md`.
      The owner merged it (`8bef3a8`), and that run tagged `v0.3.0` and published the release. The
      release notes contain no closing keywords.

## Test status

- `bats tests/` reports 87 of 87 ok. `actionlint` reports no findings; it also resolves the local call in
  `release-please.yml` and checks its `secrets:` against `release.yml`.
- The command of every passing entry in `features.json` exits 0.
- No regressions: the 59 tests that existed before all pass.

## Amendment after release (#25)

`changelog-type: github` opened a patch release on every push, docs and CI included, because GitHub's
notes are never empty and release-please skips only an empty changelog (#24, lesson 004). #25 replaced it
with `changelog-sections`, and squash merges now carry the PR title and a blank body. Release PR #23,
rewritten after the merge, lists only #25 and contains no closing keyword.

## Decisions made during implementation

- **No version file.** `simple` updates `version.txt` only if it exists (lesson 003). The tag is the
  version, and a test keeps a version file from appearing.
- **`permissions: {}` on the job.** `RELEASE_TOKEN` makes every API call, so `GITHUB_TOKEN` needs no scope.
- **`bump-minor-pre-major: true`.** Below 1.0.0 a breaking change bumps the minor, as v0.1.0 to v0.2.0 did.
- **This repository calls `release.yml` by path.** A SHA pin cannot name the commit that adds it, and by
  path the merge that changes the workflow is the run that exercises it.
- **No `bootstrap-sha`.** The tag `v0.2.0` is a precondition of the merge anyway: release-please finds the
  last release by it. A `bootstrap-sha` would be dead config after the first release.
- **`target_branch`, empty by default** (review). Empty is the default branch, so rule 4 holds and a caller releasing another branch can say so.
- **Root package only** (review, declined). The outputs are the root package's; path outputs can be added later without a breaking change.
- **Three outputs.** `release_created`, `tag_name` and `version`. Adding one later is not breaking;
  removing one is.
