# TASK-002 — Add repository architecture rules

**Milestone:** Milestone 0 — Project foundation

**Priority:** P0 — Required for the first working reader

Create `AGENTS.md` containing:

* Approved top-level modules.
* Stable-ID rules.
* Maximum folder-depth rules.
* File-budget rules.
* Dependency boundaries.
* Instructions against temporary report files.
* Requirement to list files before implementation.

## Acceptance criteria

* Agents cannot create new top-level modules without approval.
* Temporary agent notes are stored under `.agent/`.
* `.agent/` is excluded from Git unless explicitly needed.
