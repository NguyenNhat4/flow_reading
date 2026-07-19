# Project

Local-first Flutter Android EPUB reader with optional contextual AI features.

The application imports EPUB files into canonical content, paginates that
content for reading, and attaches state and future intelligence artifacts to
stable content identifiers. A physical Android device is normally connected
through USB.

## Start here

For each task:

1. Read the assigned task under `tasks/active/`.
2. Consult `docs/lib-structure.md` to understand what each file and folder does without scanning the codebase.
3. Read `docs/context-map.md` to locate relevant references.
4. Use the relevant skill for the task.
5. If your task involves adding, removing, or changing the purpose of any file in the `lib/` directory, you MUST update `docs/lib-structure.md` (and its sub-layer files) to reflect these changes.

## Session Routines (Clock-in & Clock-out)

### At session start (clock in)
1. Read `PROGRESS.md` for current state
2. Read `DECISIONS.md` for important decisions
3. Run `make check` to confirm repo is in consistent state
4. Continue from `PROGRESS.md` "Next Steps" section

### Before session end (clock out)
1. Update `PROGRESS.md`
2. Run `make check` to confirm consistent state
3. Commit all completed work

## Session Document and Checkpoint Roles

* **Decision log (`DECISIONS.md`)**: Record important design decisions and reasons. No need for detailed design documents — just "what decision, why, when".
* **Progress file (`PROGRESS.md`)**: The most basic state persistence file.
* **Git commits as checkpoints**: Commit after completing each atomic unit of work. Commit messages should explain what was done and why. These are free, automatically versioned state snapshots.

## Approved application structure

must follow architectural best pratices skill or flutter-apply-architecture-best-practices/skills to implement feature.
