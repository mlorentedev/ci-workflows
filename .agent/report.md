# Run report: ciw-20261112T0745Z-pra

Envelope: `.agent/unattended.yml` (82dc8ff). Merge authority: never. Every PR
touches `.github/workflows/`, which the merge grant excludes.

## Queue (4 of 4 worked)

| Issue | PR | Change | Local evidence |
|---|---|---|---|
| #85 | #94 | publish guard `if:` uses `!cancelled()` instead of `always()` | bats 265/265 |
| #91 | #96 | caller and kit share the comment group only for `/review` | bats 265/265 |
| #92 | #97 | `PR_REVIEWER__INLINE_KEY_ISSUES: true` on all three PR-Agent steps | bats 265/265 |
| #88 + #87 | #100 | NaN step: `MAX_MODEL_TOKENS` 32000, `AI_TIMEOUT` 300, step bound 17 min, budget test; lesson 013 | bats 269/269, actionlint |

## For the owner

- Merge order: #94 and #97 both add a rule at the same spot in
  `tests/pr-agent-shape.bats` and in the bad fixture. Whichever merges second
  needs a rebase.
- #96: adopters' callers keep the old `'/'` key until their next caller touch.
  The PR body says so.
- #100: adopters may drop `max_model_tokens` and `ai_timeout` from
  `.pr_agent.toml` on their next pin bump. The env values win either way.
- CodeRabbit hit its OSS limit on #94, #96 and #97. The PR-Agent review is the
  one reviewer that ran.

## Incidents

- The shared GraphQL rate limit was exhausted mid-run. Comments, assignees and
  the PR were done over REST. Board fields and `gh pr ready` waited for the
  reset.
- A rebase of #100 onto main was declined (force-push). Main gained only a docs
  commit (#95), so the branch stays behind without a conflict.
