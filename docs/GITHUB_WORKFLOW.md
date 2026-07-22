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
2. Create/work on `develop` (or a short-lived feature branch)
3. Implement + close the GitHub issue with a completion comment
4. Commit with **Preshan** author + **Cursor Agent** committer / Co-authored-by
5. Cut a GitHub Release when an installable Android build is ready

## Priority
- Issue labels: `priority:critical|high|medium|low`
- Project field: P0 / P1 / P2

## Recommended Insights charts (PM)

GitHub does **not** allow creating Insights charts via API — add them once under **Insights → + New chart** using these recipes. Keep the default **Burn up** chart.

Filter all charts with `is:issue` (unless noted).

### 1. Status flow (board health)
- **Name:** Status by count  
- **Layout:** Stacked column (or pie)  
- **X-axis / group:** **Status**  
- **Purpose:** See Backlog vs Ready vs In progress vs Done at a glance

### 2. Priority breakdown
- **Name:** Open by Priority  
- **Layout:** Pie or stacked column  
- **Group:** **Priority** (P0 / P1 / P2)  
- **Filter:** `is:issue is:open`  
- **Purpose:** Confirm P0/P1 aren’t drowning under nice-to-haves

### 3. Sprint / iteration load
- **Name:** Items by Iteration  
- **Layout:** Stacked column  
- **Group:** **Iteration**  
- **Purpose:** Work committed per sprint (Sprint 1–6)

### 4. Labels — current vs future
- **Name:** Sprint labels  
- **Layout:** Stacked column or pie  
- **Group:** **Labels** (or filter `label:sprint:future` vs `label:sprint:6`)  
- **Filter:** `is:issue is:open`  
- **Purpose:** Separate deferred FCM/future work from current sprint

### 5. Module hotspot (optional)
- **Name:** Open by module  
- **Layout:** Bar  
- **Group:** **Labels**  
- **Filter:** `is:issue is:open`  
- **Purpose:** Which domain still has open work (messaging, notifications, etc.)

### How to read Burn up (existing)
- Green / total scope = work in the project over time  
- Purple / completed = closed or Done  
- Gap = remaining scope (includes `sprint:future` unless you filter it out)  
- Tip: for “current sprint only,” add filter `label:sprint:6` (or the active sprint label)
