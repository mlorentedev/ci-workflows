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
      changelog is GitHub's…", "the release writes no version file"; the manifest is `0.2.0`.
- [x] Criterion 4. `release-callers.bats`, 9 tests over `fixtures/release-callers/{dotfiles,pollex}.yml`
      and `.github/workflows/release-please.yml`, each rule also failing on
      `fixtures/release-caller-shape-bad.yml`.
- [x] Criterion 5. README `## release` and "How this repository is released"; AGENTS.md.
- [ ] Criterion 6. Pending the first run after merge: a release PR labelled `autorelease: pending`, then
      the tag and the release when the owner merges it.

## Test status

- `bats tests/` reports 84 of 84 ok. `actionlint` reports no findings; it also resolves the local call in
  `release-please.yml` and checks its `secrets:` against `release.yml`.
- The command of every passing entry in `features.json` exits 0.
- No regressions: the 59 tests that existed before all pass.

## Decisions made during implementation

- **No version file.** `simple` updates `version.txt` only if it exists (lesson 003). The tag is the
  version, and a test keeps a version file from appearing.
- **`permissions: {}` on the job.** `RELEASE_TOKEN` makes every API call, so `GITHUB_TOKEN` needs no scope.
- **`bump-minor-pre-major: true`.** Below 1.0.0 a breaking change bumps the minor, as v0.1.0 to v0.2.0 did.
- **This repository calls `release.yml` by path.** A SHA pin cannot name the commit that adds it, and by
  path the merge that changes the workflow is the run that exercises it.
- **No `bootstrap-sha`.** The tag `v0.2.0` is a precondition of the merge anyway: the GitHub changelog
  generates notes from the previous tag. A `bootstrap-sha` would be dead config after the first release.
- **Three outputs.** `release_created`, `tag_name` and `version`. Adding one later is not breaking;
  removing one is.
