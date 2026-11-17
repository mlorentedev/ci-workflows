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
- [x] Criterion 3 (paragraph, registry and guard). f3 exits 0 on 2026-11-12 for the paragraph and the
      registry. The guard is f5: it exited 1 until #82 shipped in v0.8.0, and exits 0 on 2026-11-15.
      `Class:` lines on the first review with findings after each adoption merged:

      | Adopter | PR | Classes seen |
      |---|---|---|
      | garsync | [#165](https://github.com/mlorentedev/garsync/pull/165) | REAL |
      | hive | [#582](https://github.com/mlorentedev/hive/pull/582) | THEORETICAL |
      | iris | [#64](https://github.com/mlorentedev/iris/pull/64) | THEORETICAL |
      | kubelab | [#3389](https://github.com/mlorentedev/kubelab/pull/3389) | THEORETICAL |
      | mail2markdown | [#34](https://github.com/mlorentedev/mail2markdown/pull/34) | THEORETICAL |
      | pdf-modifier | [#239](https://github.com/mlorentedev/pdf-modifier/pull/239) | THEORETICAL, SPECULATIVE |
      | ts-bridge | [#755](https://github.com/mlorentedev/ts-bridge/pull/755) | THEORETICAL |
      | web | [#661](https://github.com/mlorentedev/web/pull/661) | THEORETICAL |
      | yt-metrics-cli | [#121](https://github.com/mlorentedev/yt-metrics-cli/pull/121) | THEORETICAL |
      | leaving-denver | [#282](https://github.com/mlorentedev/leaving-denver/pull/282) | THEORETICAL |
      | pollex | [#132](https://github.com/mlorentedev/pollex/pull/132) | SPECULATIVE |
      | svqtriana.github.io | [#44](https://github.com/mlorentedev/svqtriana.github.io/pull/44) | SPECULATIVE |

- [x] Criterion 4 (every adopter PR reviewed, no batch lost to the NaN slot limit) -> f4 exits 0 on
      2026-11-12. The PRs went ready in batches of four (hive, kubelab, garsync, iris first).

## Test status

- Test suite: `bash -c "$(jq -r '.[N].verification' features.json)"` for f1 to f5 on 2026-11-12:
  f1 0, f2 0, f3 0, f4 0, f5 1 (`Error: no matches found`: the guard step does not exist before #82).
  Again on 2026-11-15, on main at 8427ebb: f1 0, f2 0, f3 0, f4 0, f5 0 (the last line of f5 is
  `ok 13 this repository's own toml and registry agree`).
- Caller rollout of v0.8.0 (#113): all twelve callers pin `pr-agent.yml@9b34f5b` with a
  `concurrency.group` byte-identical to the kit's, checked on each default branch on 2026-11-15:
  for each adopter, fetch `.github/workflows/pr-agent.yml` with `gh api .../contents/...` (raw), require
  `pr-agent.yml@9b34f5b2815a3090d77d7589ef8bcc5087045544` in it and compare `yq -r .concurrency.group`
  with `kit/pr-agent.yml`'s. Output: one `<repo> ok` line per adopter, then `12/12`.
- leaving-denver's `pr-agent` workflow was found `disabled_manually` (since 2026-11-13, after #282's review),
  so its v0.8.0 pin had never run. Re-enabled on 2026-11-15 (`state=active`); its next PR is the first
  run on v0.8.0, checked with the 2026-11-17 Renovate run.
- Manual smoke test: the first post-adoption reviews above carry `Class:` lines in each of the twelve
  repositories, which is the paragraph read from the default branch.
- No regressions in existing test suite: yes (`bats tests/*.bats` green on main).

## Decisions made during implementation

- The adopter PRs opened on v0.5.0 and were moved to v0.6.0 before merge, so the fleet merged on one pin.
- pdf-modifier keeps `persistent_finding_state = false` in its own `.pr_agent.toml`: its old workflow set it in
  the env block, and the shared workflow does not (lesson 016).
- Fixes found while adopting went to the shared workflow, not to the adopters: #85 (#94), #91 (#96),
  #92 (#97), #87 and #88 (#100). Rolling the #96 key out to the callers is #103.
- Callers that differ from the kit: svqtriana.github.io does not pass `PR_AGENT_ANTHROPIC_API_KEY` (the
  reason is a comment in its caller); kubelab, web and yt-metrics-cli pass extra inputs (their own reviewer
  pool, `declare_unreviewed`, a job `if:`).

- The first pre-archive review (nan/glm5.3-flash, 2026-11-15, FAIL) found the kit inside this folder, read by
  two tests and the guard's error message, so archiving would have broken `bats tests/`. #127 moved it to
  `pr-agent/` at the repository root and added a `tests/specs.bats` check against paths into active spec
  folders (lesson 020). Where this record and tasks.md say `kit/`, the files are now in `pr-agent/`.
- That review's Minor findings: a prose `Class:` mention and the paragraph's position are #128; porting the
  guard script to `dotf` is declined, because fork 2b chose the guard in the shared workflow and
  `tests/class-guard.bats` runs its script.

- The second pre-archive review (nan/deepseek-v4-flash, PASS-WITH-GAPS) is dispositioned as follows.
  The guard accepting a superset spelling such as `` `Class: REAL` `` is added to #128, which already
  replaces the substring match. The claim that a bare `/review` or `/Review` gets a group of its own is
  refuted: the key tests `startsWith(format('{0} ', body), '/review ')`, so a bare `/review` becomes
  `/review ` and matches, and Actions' `startsWith` ignores case. The `kit/` paths left in proposal.md and
  tasks.md stay as written, translated in the entry above, because editing the contract after review
  would stale it. f1 accepting any pinned SHA is the intended split: the criterion is "pinned by commit",
  and the exact v0.8.0 pin is release rollout (#113), checked above at 12/12.

## Promotion candidates

- [x] Lesson for the repo's `docs/lessons/`? yes: docs/lessons/lesson-016-a-shared-workflow-drops-the-callers-env-block.md
- [x] ADR-worthy decision for the repo's `docs/adr/adr-XXX.md`? no: the one decision (guard the class paragraph in the shared workflow, fork A2) is recorded in the archived proposal and touches only this repository's own workflow
- [x] New pattern candidate for `00_meta/patterns/`? Only if this recurs in >1 project. no: moving a fleet onto one shared caller is already ADR-001's model; nothing here recurs outside it

## Archive checklist

- [ ] `proposal.md` frontmatter set to `status: archived`
- [ ] Folder moved: `specs/CI-007-fleet-pr-agent/` -> `specs/archive/CI-007-fleet-pr-agent/`
- [ ] Bitácora board ticket for this spec moved to Done / closed with PR link (ADR-018)
- [ ] Promotions above executed (if any)
