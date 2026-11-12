---
tags: [spec, verification, templates]
created: "2026-11-11"
id: "CI-010-docker-build"
type: spec-verification
status: active
owner: manu
---

# Verification - CI-010-docker-build

## Evidence

Map every acceptance criterion from `proposal.md` to concrete proof (commit hash, test name, or observed behavior).

- [ ] AC1 -> #102: `tests/docker-build.bats`, which asserts the scope defaults to the image and that no input
      value leaves it empty. Checked when #102 merges.
- [ ] AC2 -> `tests/docker-publish-shape.bats`, which asserts push by digest, one scan and gate per platform, no tag before
      the gate, and secrets by name. `tests/secrets-contract.bats` picks the workflow up. Checked when the second PR merges.
- [ ] AC3 -> #102, run on 1c41729 (2026-11-12): `smoke-docker-build-warm` rebuilt the fixture in 7 s on a fresh runner,
      after `importing cache manifest from gha`, and read the cold job's stamp. The stamp was a seconds timestamp then,
      since busybox `date` has no `%N`; 2b4a6b5 switched it to a random id. Checked when #102 merges.
- [ ] AC4 -> `tests/docker-callers.bats` over the web, kubelab and dotfiles fixtures. Checked when the third PR merges.
- [ ] Criterion 5 -> per adopter: the PR, and the build time or cache restore measured

## Test status

- `bats tests/`: 303 tests, 0 failures. `actionlint`: clean.
- No regressions in the existing suite.

## Decisions made during implementation

- `docker-publish.yml` calls the composite as `mlorentedev/ci-workflows/.github/actions/docker-build@<sha>`, not `./`.
  Inside a reusable workflow, `./` is the caller's checkout. Until a release ships the composite, the pin is #102's
  head; it is repointed at the release.
- The composite gained `push-by-digest`, which pushes the image untagged, so `docker-publish.yml` names no tag before
  its gate. It lands with the composite in #102: pinned at a commit without it, the input would be ignored and the
  build would push nothing, leaving the scan an empty digest.
- Secrets are `REGISTRY_USERNAME` and `REGISTRY_TOKEN`, the repository's uppercase convention (`RELEASE_TOKEN`).
  The proposal's lowercase names refer to the same secrets.

-
-

## Promotion candidates

Answer each line `yes: <path>`, naming the file you promoted, or `no: <reason>`. `dotf spec archive` refuses a line left unanswered, a `no` without a reason, and a `yes` whose file does not exist; a `00_meta/` path is looked up in the vault.

- [ ] Lesson for the repo's `docs/lessons/`? <yes: path / no: reason>
- [ ] ADR-worthy decision for the repo's `docs/adr/adr-XXX.md`? <yes: path / no: reason>
- [ ] New pattern candidate for `00_meta/patterns/`? Only if this recurs in >1 project. <yes: path / no: reason>

## Archive checklist

- [ ] `proposal.md` frontmatter set to `status: archived`
- [ ] Folder moved: `specs/CI-010-docker-build/` -> `specs/archive/CI-010-docker-build/`
- [ ] Bitácora board ticket for this spec moved to Done / closed with PR link (ADR-018)
- [ ] Promotions above executed (if any)
