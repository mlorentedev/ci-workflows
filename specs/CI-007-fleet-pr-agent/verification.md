---
tags: [spec, verification, templates]
created: "2026-11-10"
id: "CI-007-fleet-pr-agent"
type: spec-verification
status: active
owner: manu
---

# Verification - CI-007-fleet-pr-agent

## Evidence

Adopter PRs, all merged 2026-11-12 on the v0.6.0 pin (`2355330…`), each with a `## Review triage`:
garsync#160, hive#578, iris#61, kubelab#3319, leaving-denver#279, mail2markdown#31, pdf-modifier#236,
pollex#129, svqtriana.github.io#40, ts-bridge#729, web#652 (with web#655), yt-metrics-cli#117.
The secrets grant for the twelve is dotfiles#3366.

- [x] Criterion 1 (pinned by full SHA) -> f1 exits 0 on 2026-11-12.
- [x] Criterion 2 (no copy of the review steps) -> f2 exits 0 on 2026-11-12.
- [ ] Criterion 3 (paragraph, registry and guard). f3 exits 0 on 2026-11-12 for the paragraph and the
      registry. The guard is f5, which exits 1 until #82 ships in a release. `Class:` lines on the first
      review with findings after each adoption merged:

      | Adopter | PR | Classes seen |
      |---|---|---|
      | garsync | #165 | REAL |
      | hive | #582 | THEORETICAL |
      | iris | #64 | THEORETICAL |
      | kubelab | #3389 | THEORETICAL |
      | mail2markdown | #34 | THEORETICAL |
      | pdf-modifier | #239 | THEORETICAL, SPECULATIVE |
      | ts-bridge | #755 | THEORETICAL |
      | web | #661 | THEORETICAL |
      | yt-metrics-cli | #121 | THEORETICAL |
      | leaving-denver, pollex, svqtriana.github.io | none yet | no review with findings since adoption |

- [x] Criterion 4 (every adopter PR reviewed, no batch lost to the NaN slot limit) -> f4 exits 0 on
      2026-11-12. The PRs went ready in batches of four (hive, kubelab, garsync, iris first).

## Test status

- Test suite: `bash -c "$(jq -r '.[N].verification' features.json)"` for f1 to f5 on 2026-11-12:
  f1 0, f2 0, f3 0, f4 0, f5 1 (`Error: no matches found`: the guard step does not exist before #82).
- Manual smoke test: the first post-adoption reviews above carry `Class:` lines in each of the nine
  repositories, which is the paragraph read from the default branch.
- No regressions in existing test suite: yes (`bats tests/*.bats` green on main).

## Decisions made during implementation

- The adopter PRs opened on v0.5.0 and were moved to v0.6.0 before merge, so the fleet merged on one pin.
- pdf-modifier keeps `persistent_finding_state = false` in its own `.pr_agent.toml`: its old workflow set it in
  the env block, and the shared workflow does not (lesson 016).
- Fixes found while adopting went to the shared workflow, not to the adopters: #85 (#94), #91 (#96),
  #92 (#97), #87 and #88 (#100). Rolling the #96 key out to the callers is #103.

## Promotion candidates

- [x] Lesson for the repo's `docs/lessons/`? yes: docs/lessons/lesson-016-a-shared-workflow-drops-the-callers-env-block.md
- [ ] ADR-worthy decision for the repo's `docs/adr/adr-XXX.md`? <yes: path / no: reason>
- [ ] New pattern candidate for `00_meta/patterns/`? Only if this recurs in >1 project. <yes: path / no: reason>

## Archive checklist

- [ ] `proposal.md` frontmatter set to `status: archived`
- [ ] Folder moved: `specs/CI-007-fleet-pr-agent/` -> `specs/archive/CI-007-fleet-pr-agent/`
- [ ] Bitácora board ticket for this spec moved to Done / closed with PR link (ADR-018)
- [ ] Promotions above executed (if any)
