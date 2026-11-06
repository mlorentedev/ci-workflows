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

- `bats tests/` reports 88 of 88 ok (87 before #25 added one). `actionlint` reports no findings; it also resolves the local call in
  `release-please.yml` and checks its `secrets:` against `release.yml`.
- The command of every passing entry in `features.json` exits 0.
- No regressions: the 59 tests that existed before all pass.

## Amendment after release (#25)

`changelog-type: github` opened a patch release on every push, docs and CI included, because GitHub's
notes are never empty and release-please skips only an empty changelog (#24, lesson 004). #25 replaced it
with `changelog-sections`, and squash merges now carry the PR title and a blank body. Release PR #23,
rewritten after the merge, lists only #25 and contains no closing keyword.

Notes from the independent review (`review.md`):

- `tasks.md` still lists `changelog-type: github` among the settled decisions. It records what was
  settled before implementation and stays as written; this amendment supersedes it.
- That a hidden-type push cuts no release is shown by the source rule (lesson 004) and by #23 omitting
  #21 and #22. Observed live on the merge of #26 (`7c58267`), a `docs:` change: the release-please run
  succeeded, #23 still lists only #25 and changes only the manifest and `CHANGELOG.md`, and no other
  release PR opened. #23's head moved (`fcd5c94` to `7ef113b`) because release-please rebuilds the
  release branch on the new `main` at every push; its content, not its head, is the signal.
- No `closes` rests on the repository's squash defaults, which are not retroactive. Merge commits and
  rebase merges are still allowed and still carry bodies (dotfiles#3169, dotfiles#3198).
- The token step's two script tests run under `bats tests/`, not under a `features.json` command.
- A breaking change opens a release whatever its type: `docs!:` is hidden as `docs` but release-please
  still writes its breaking-change note, so the changelog is not empty. That is intended (README, "Mark it
  with `!`"), and it is why criterion 3 reads "visible", not "releasable".

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

## Promotion candidates

- [x] Lesson for the repo's `docs/lessons/` (the version file)? yes: docs/lessons/lesson-003-release-please-simple-writes-no-version-file-it-does-not-find.md
- [x] Lesson for the repo's `docs/lessons/` (release noise)? yes: docs/lessons/lesson-004-github-release-notes-are-never-empty.md
- [x] ADR-worthy decision for the repo's `docs/adr/adr-XXX.md`? no: it implements ADR-001 decision 6 and adds no new structural decision
- [x] New pattern candidate for `00_meta/patterns/`? no: blank squash bodies as the fix for release-please closing references is being applied to dotfiles (dotfiles#3169, dotfiles#3198); it becomes a pattern once a second repository confirms it
