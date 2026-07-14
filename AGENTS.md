## Project

This is a local-first Flutter Android EPUB reader with contextual AI features.

The application imports EPUB books, converts them into a canonical book representation, paginates content for reading, and attaches reading state, annotations, translations, and AI artifacts to stable content identifiers.

## Required reading order

For every task, read only:

1. This file.
2. `docs/context-map.md`.
3. The assigned task file under `tasks/active/`.
4. Additional documents explicitly listed in the task file.

Do not read the full repository or all documentation unless the task requires it.

## Approved modules

```text
lib/
├── app/
├── platform/
├── books/
├── reader/
├── intelligence/
├── settings/
└── shared/
```

Do not create a new top-level module without explicit approval.

## Dependency rules

```text
books          -> platform, shared
reader         -> books, platform, shared
intelligence   -> books, reader, platform, shared
settings       -> platform, shared
app            -> all feature modules
```

Additional rules:

* `books` must not depend on `reader` or `intelligence`.
* `reader` must not depend on `intelligence`.
* Widgets must not directly access databases, files, HTTP clients, secure storage, or EPUB parsers.
* Provider-specific AI code must stay inside the intelligence module.
* Platform integrations must stay inside the platform module.

## Critical invariants

These rules must never be violated:

1. Visual page numbers are temporary and must not be used as permanent identifiers.
2. Reading positions must use stable content identifiers and character offsets.
3. Highlights, notes, translations, bookmarks, and AI references must attach to stable source text.
4. Pagination is derived from canonical content and reader layout.
5. The original EPUB must remain unmodified.
6. Local reading must not require an account or internet connection.
7. AI provider keys must not be committed, logged, or stored in the normal application database.
8. The local database is the primary source of truth.
9. Synchronization must be optional.
10. Do not introduce synchronization before local behavior is reliable.

## Repository structure rules

* Prefer modifying an existing file over creating a new abstraction.
* Keep feature folders flat until they contain more than approximately eight related files.
* Do not repeat `domain/application/infrastructure/presentation` inside every feature.
* Do not create a repository for every database table.
* Do not create placeholder files for future functionality.
* Do not create implementation reports, completion summaries, backups, or temporary Markdown files.
* Store temporary reasoning under `.agent/`, which must not be committed.
* Avoid paths deeper than four meaningful folder levels.

## Before implementation

Before editing code, provide:

```text
Goal:
Relevant files:
Files to modify:
Files to create:
Assumptions:
Risks:
```

Do not modify files before producing this brief plan.

## File budget

Unless the task explicitly says otherwise:

* Modify no more than five existing files.
* Create no more than two new production files.
* Create no new top-level folders.
* Do not add a dependency without explaining why existing dependencies are insufficient.

If the task cannot fit within this budget, stop and propose a revised plan before implementing.

## Implementation rules

* Implement only the assigned task.
* Do not perform unrelated cleanup.
* Do not build future requirements preemptively.
* Use the smallest design that satisfies the acceptance criteria.
* Reuse existing models and services where appropriate.
* Do not silently change public interfaces outside the task scope.
* Do not invent requirements missing from the task.
* Add comments only where the reason is not clear from the code.

## Testing rules

Run the narrowest relevant checks first.

Typical order:

```bash
dart format <changed-files>
flutter analyze
flutter test <relevant-test-file>
```

Run the complete test suite only when:

* Shared models changed.
* Database schema changed.
* Public interfaces changed.
* The task explicitly requires it.

## Completion response

At completion, report only:

```text
Implemented:
Changed files:
Validation:
Remaining issues:
```

Do not create a separate completion document.
