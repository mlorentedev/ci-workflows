# Adopter recipe

Gathered at arming from feat-issue-15's twelve PR-Agent adoption PRs on 2026-11-12, and from this run's calibration.

## Every adopter

- Branches fall BEHIND within hours. Run `gh pr update-branch` before reporting. If the remote has an update-branch merge, pull before pushing.
- `dotf pr triage-queue --pr N` reads inline comments only. Read PR-Agent's Guide yourself, too.
- CodeRabbit is often rate-limited. Say so in the triage: a notice is not a review.
- knowledge-gate was never hit by workflow-only PRs. These PRs touch docs/lessons, so check whether the repo runs it, and fill `## Knowledge`.
- `dotf lessons fmt` changes only frontmatter (it quotes `id` and adds `title`), and does so in most lessons: 30 of 31 in pdf-modifier, 37 of 59 in ts-bridge. It goes in its own commit.

## Per repository

| Repo | Required checks or traps |
|---|---|
| kubelab | Validate, Detect Changes, review-attestation, Tests, deploy-shape. Shows BLOCKED until all land. Carries merge-grant.yml, but the run never merges. |
| hive | check (3.12), check (3.13), cross_worker_lock on ubuntu and windows. Hand-resolved conflict today. |
| web | "PR gate", GitGuardian. "Release closing refs" also runs. |
| ts-bridge | test, lint, security, hygiene. Keep the `hygiene` job id. |
| pdf-modifier | `test_reviewer_pool_contract.py` rejects review markers not in `markers_measured.observed_in` (pdf-modifier#237). |
| svqtriana.github.io | `npm run check:harness` validates workflows and harness/*.json together. No branch protection. |
| yt-metrics-cli | Tests pin `.pr_agent.toml` keys. |
