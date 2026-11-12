# Run report: ciw-20261112T0708Z-renovate

Armed 2026-11-12T07:08Z, ended 2026-11-12T11:55Z (expiry 19:08Z). Reason: owner-blocked. Every remaining item waits on a merge only the owner may make.

## Landed under the grant
- #95 (closes #74): Renovate secret-exposure inventory, lesson 014.
- #101 (refs #30): CI-003 AC6 amended for exceptions; merged by hand over REST after `dotf pr land` hit the GraphQL limit; hygiene on main checked afterwards.

## Open, for the owner
- CI-010, three stacked PRs, all `.github/` (outside the grant), CI green, triaged:
  - #102 composite + smokes. 373 executable lines with tests, over the 300 cap after the review fixes and the push-by-digest move from #104. Disclosed, not split again.
  - #104 docker-publish.yml (226), pins the composite at 8ed7a7d; repoint to the release commit after #102 lands.
  - #105 caller fixtures + README (141).
- Adoption PRs (Renovate preset v0.6.0): iris#62, kasa-provisioner#16, mail2markdown#32, nan-video-pipeline#15, pdf-modifier#238, svqtriana.github.io#41. pdf-modifier's `mutation` check fails before this change (pdf-modifier#229).
- Filed: #106 (docker-build logic into dotf), pdf-modifier#241.
- Delete the orphan remote branch `feat/issue-11-docker-publish` (60d3919, superseded by #104/#105).
- Lesson candidate the envelope did not cover: a composite's guard on a boolean input must parse it the way the action it fronts does (load: True slipped past a `= "true"` check). The other composites compare their own flags only, so the class has no other instance today.

## Not covered
- No wake-lock was taken; the machine stayed awake by being in use.
