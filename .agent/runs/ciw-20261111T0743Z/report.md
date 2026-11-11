# Run ciw-20261111T0743Z

- Armed 2026-11-11T07:43Z, closed 2026-11-11T14:55Z, before the 19:43Z expiry. Reason: queue-empty. The five items are done, and what remains waits on the owner.
- Authority: `merge: never`. Nothing was merged.
- Host: a `caffeinate` wake-lock covered the run. It died at 08:16Z and was restarted at once. The session paused from about 08:40Z to 12:00Z when the usage limit was reached, so no work ran in that window.

## Items

1. **kubelab preset pin v0.4.0 to v0.5.0:** kubelab#3271. Green, triaged, waiting on the owner.
2. **Renovate adoption:** leaving-denver#277, ts-bridge#718, yt-metrics-cli#114, garsync#158, hive#571, web#643 and pollex#127. All green and triaged.
   - garsync got two fixes from review: ADR-014's exposure and reopening triggers in the rules, and the cutover date replaced by a PR reference.
   - Every PR body's bare `#30` now names ci-workflows#30.
   - dotfiles is excluded, because its code reads `dependabot.yml`: dotfiles#3313.
3. **Spec #13, CI-009 bot lane:** #72. Two review rounds applied. The main correction is that the escape is a grant, so it keys on provenance only.
4. **Spec #11, CI-010 docker build:** #76. One review round applied.
5. **Runner-load sweep:** posted on #14. web#646 is new; every other pattern was already tracked.

## Tickets filed

- **ci-workflows:**
  - #73: three preset defects (the Actions group, Python lower bounds, the hourly limit);
  - #74: Renovate PRs run with the repository's secrets.
- **dotfiles:**
  - #3313: dotfiles' own Renovate adoption;
  - #3317: `declare-unreviewed --diff lane` and `verify-pin-bump`.
- **Fleet repositories:**
  - hive#572 and yt-metrics-cli#115: documentation drift;
  - kubelab#3299: unscoped buildx cache;
  - web#646: cheap checks in one job.

## Owner decisions

1. #74: whether the adoption PRs wait for `minimumReleaseAge` in the preset. Recommended: wait, because Monday's run is the first exposure.
2. CI-009 Risks: the release age and its residual risk, the merging token, the Renovate App (it now also decides whether Renovate PRs can be declared unreviewed), the production paths, and the opt-in file.
3. pollex#127: confirm the `site/**` Astro rule.
4. Merge kubelab#3271, the seven adoption PRs, #72 and #76.
5. Carried over from the peer: dotfiles#3305's OS-sensitive path set and dotfiles#3306's required-check switch to `gate`.

## Not done

- CI-003's per-repository adoption lines wait for the merges, and will go in as one PR.
- Hygiene adoption was not started. The queue was full, and it adds fleet PRs to a review backlog already waiting on the owner.
