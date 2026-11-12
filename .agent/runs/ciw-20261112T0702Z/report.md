# Run ciw-20261112T0702Z: report

Armed 2026-11-12T07:06:00Z, expires 19:06:00Z. `merge: never`: every PR below waits for the owner.

## Outcome per queue item

| # | Item | Result |
|---|---|---|
| 1 | CI-005 smoke record (#31) | ci-workflows#98: AC2 evidenced (run 43173027029), triaged |
| 2 | CI-006 first consumer (#32) | ts-bridge#741: green, triaged; after merge, record the deploy run and archive CI-006 |
| 3 | Adoption, batch 1 | pdf-modifier#239, pollex#131, yt-metrics-cli#121, mail2markdown#34, iris#64: open, triaged |
| 4 | Pinned-actions input (AC3) | **Parked.** dotf 0.80.0 has no rule selector and does not scan `.github/actions/*/action.yml`; dotfiles#3386 filed; #31 comment 6817799991 |
| 5 | Adoption, batch 2 | hive#582 open. Parked: ts-bridge, garsync, svqtriana.github.io, web, kubelab (below) |

## Parked adopters (comments on ci-workflows#31)

| Repo | Why | Options |
|---|---|---|
| ts-bridge | `fmt` sentence-cases one lesson H1 (lesson-045), a body change | accept the hunk / fix the heading first |
| garsync | lesson-019 has no frontmatter and no date, `fmt` stops | add `created: "2026-09-07"` / inline `**Date:**` |
| svqtriana.github.io | lessons are date-named; dotf sees none, the composite would pass on nothing | rename to `lesson-NNN` / dotf learns the scheme |
| web | `site/tests/check-lessons.test.mjs` and `delivery-gate.test.mjs:281` pin the script and the index | rewrite those tests in the PR / leave web out |
| kubelab | application code (`toolkit/features/lessons_index.py`, curator) and four tests read the indexes; 14 index files exceed max_files | a kubelab spec first / leave kubelab out |

## Owner actions

- yt-metrics-cli#121: `AGENTS.md` lines 82, 84, 95 still name the script and index (frozen for the run); replacement text is in the PR body.
- iris#64: the `lessons-fmt` pre-commit hook was dropped, not replaced; the `pre-commit` job in `ci.yml` installs no dotf.
- Decide each parked adopter (A or B) on #31.

## Defects found and filed

- dotfiles#3386: `dotf lint fleet` cannot run one rule, and `fleet/sha-pin` skips local composite actions.

## Notes for the next run

- The frontmatter-only check must compare hunk ranges with the frontmatter's closing `---` on both sides; a line-number heuristic missed ts-bridge's H1.
- A fresh worktree of a uv project needs `uv sync --all-groups` before a commit whose hooks run mypy.

## Close

- Every opened PR passes `dotf pr triage-queue --pr N` (exit 0); ci-workflows#98 was behind and its branch was updated again.
- Board: #31 and #32 read In Progress (set after the GraphQL limit reset).

## After the window (interactive, owner present)

- Parked adopters, option A per the owner: garsync#165, ts-bridge#755, web#661, svqtriana.github.io#43, all green and triaged. kubelab left out.
- CI-006: review PASS; ci-workflows#110 archives the spec and closes #32, green and triaged.
- Filed: dotfiles#3415, `dotf lessons fmt --check` passes a lesson whose filename it does not recognise (raised on svqtriana.github.io#43).
- Each PR above passes `dotf pr triage-queue --pr N` (exit 0). CodeRabbit hit its free limit on #110 and on the last push of garsync#165 and web#661; the triage comments say so.
