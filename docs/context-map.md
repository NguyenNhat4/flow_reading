# docs/context-map.md

# Context Map

Use this file to determine which documentation is relevant to the assigned task.

Do not read every linked document by default.

## Always read

* `AGENTS.md`
* The assigned file under `tasks/active/`

## Read by task area

| Task area                   | Read                                                                 | Main code location                 |
| --------------------------- | -------------------------------------------------------------------- | ---------------------------------- |
| EPUB import                 | `docs/data-model.md`, EPUB import section of `docs/architecture.md`  | `lib/books/`                       |
| Canonical book model        | `docs/data-model.md`, `docs/invariants.md`                           | `lib/books/`                       |
| Stable IDs and text anchors | `docs/invariants.md`, `docs/data-model.md`                           | `lib/books/`, `lib/shared/`        |
| Library UI                  | Relevant task only                                                   | `lib/books/`                       |
| Pagination                  | Pagination section of `docs/architecture.md`, `docs/invariants.md`   | `lib/reader/`                      |
| Reading position            | `docs/invariants.md`, reader section of `docs/architecture.md`       | `lib/reader/`                      |
| Highlights and notes        | `docs/invariants.md`, annotation section of `docs/data-model.md`     | `lib/reader/`                      |
| AI provider                 | Intelligence section of `docs/architecture.md`                       | `lib/intelligence/`                |
| AI context builder          | Intelligence section of `docs/architecture.md`, `docs/invariants.md` | `lib/intelligence/`                |
| Translation                 | Translation section of `docs/architecture.md`, `docs/invariants.md`  | `lib/intelligence/`, `lib/reader/` |
| Chapter overview            | Intelligence section of `docs/architecture.md`                       | `lib/intelligence/`                |
| Settings                    | Relevant task only                                                   | `lib/settings/`                    |
| Local persistence           | Persistence section of `docs/architecture.md`, relevant data models  | `lib/platform/`                    |
| Synchronization             | Sync section of `docs/architecture.md`, `docs/invariants.md`         | `lib/sync/`                        |
| Product clarification       | Relevant requirement inside `docs/product-plan.md`                   | Varies                             |

## Documentation roles

### `docs/product-plan.md`

Contains the complete product requirements.

Read it only when:

* The task file references a specific requirement ID.
* Acceptance criteria are ambiguous.
* Product behavior must be clarified.

Do not read it merely to implement a normal technical task.

### `docs/architecture.md`

Contains system boundaries and component interactions.

Read only the section linked by the task file.

### `docs/invariants.md`

Contains rules that must remain true across modules.

Read for tasks involving:

* Stable identifiers.
* Reading position.
* Pagination.
* Annotations.
* Translations.
* AI references.
* Synchronization.

### `docs/data-model.md`

Contains canonical persisted and in-memory models.

Read for tasks that create or change stored data.

## Source-of-truth priority

When information conflicts, use this order:

1. Assigned task acceptance criteria.
2. `docs/invariants.md`.
3. `docs/architecture.md`.
4. `docs/data-model.md`.
5. `docs/product-plan.md`.
6. Existing implementation.

Do not silently resolve meaningful conflicts. Report them before implementation.

## Repository inspection rules

Start by inspecting only:

1. Files explicitly listed in the task.
2. Direct imports of those files.
3. Tests for the affected component.

Expand inspection only when a dependency or interface requires it.

Do not recursively inspect every file in `lib/`.
