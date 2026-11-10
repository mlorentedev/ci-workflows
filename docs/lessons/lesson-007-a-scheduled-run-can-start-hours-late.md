---
id: "lesson-007-a-scheduled-run-can-start-hours-late"
type: lesson
status: active
title: "A scheduled run can start hours late"
created: "2026-11-09"
---

# A scheduled run can start hours late

## Context

`renovate.yml` runs on the cron `17 1 * * 1`, and the preset opened updates only
between 00:00 and 06:59 on Monday, Europe/Madrid, which ends at 05:59 UTC. The
cron fell about five hours inside that window.

## Problem

On 2026-11-09 GitHub started the 01:17 UTC run at 07:54 UTC. kubelab's own
Renovate cron slid the same way. Every repository reported `"result": "done"`,
the job was green, and no update opened, because the window had closed before
the run began. GitHub documents that scheduled runs can be delayed under load;
the start of an hour on Monday is one of its busiest slots.

## Solution

- Do not pair a GitHub cron with a narrow time window in the tool it starts.
  Give the tool's window a margin of a day, and let the rate limits
  (`prHourlyLimit`, `prConcurrentLimit`) do the pacing. The preset's schedule is
  now all of Monday (#48).
- Read a scheduled run's start time, not its cron line, when a run did nothing.
