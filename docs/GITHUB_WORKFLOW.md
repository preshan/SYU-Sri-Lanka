# GitHub Project workflow (SYU Sri Lanka)

Board: https://github.com/users/preshan/projects/2  
Insights: https://github.com/users/preshan/projects/2/insights

## Status meanings
- **Backlog** — not started / deferred (`sprint:future`)
- **Ready** — ready to pick up (epics often sit here)
- **In progress** — actively being built
- **In review** — PR / QA
- **Done** — shipped / closed

## Sprints
Use the **Iteration** field (Sprint 1–6) and `sprint:N` labels.  
Deferred work uses label **`sprint:future`** and Status **Backlog**.

## How we work
1. Pick a child issue under an epic (not the epic itself unless coordinating)
2. Work on `develop` (or a short-lived `dev/…` feature branch, then merge to `develop`)
3. Close the GitHub issue with a short completion note
4. Cut a GitHub Release when an installable Android build is ready (see [RELEASE_RUNBOOK.md](./RELEASE_RUNBOOK.md))

## Priority
- Issue labels: `priority:critical|high|medium|low`
- Project field: P0 / P1 / P2

## Insights charts (optional)

GitHub Insights charts are created in the UI (**Insights → + New chart**). Useful views:

| Chart | Group by | Filter |
|-------|----------|--------|
| Status by count | Status | `is:issue` |
| Open by Priority | Priority | `is:issue is:open` |
| Items by Iteration | Iteration | `is:issue` |
| Sprint labels | Labels | `is:issue is:open` |

Keep the default **Burn up** chart. For “current sprint only,” filter e.g. `label:sprint:6`.
