# Context Map

Use this file to determine which documentation is relevant to the assigned task.

Do not read every linked document by default.

## Always read

- `AGENTS.md`
- The assigned file under `tasks/active/`

## Read by task area

| Task area                   | Read                                                                 | Main code location                 |
| --------------------------- | -------------------------------------------------------------------- | ---------------------------------- |
| Project orientation and progress | `docs/project-architecture-guide.md`                           | All approved modules               |
| Dart and Flutter code conventions | `docs/flutter-guidelines/code-style.md`                       | All approved modules               |
| Application patterns, state, routing, serialization, logging, and code generation | `docs/flutter-guidelines/application-patterns.md` | `lib/app/`, feature modules |
| Testing and API documentation | `docs/flutter-guidelines/testing-and-documentation.md`             | `test/`, affected production module |
| UI, theming, layout, assets, typography, and accessibility | `docs/flutter-guidelines/ui-and-accessibility.md` | Widget and theme files |
| EPUB validation             | Validation section of `docs/epub-import.md`                         | `lib/books/epub_validator.dart`    |
| Original EPUB storage       | Storage lifecycle section of `docs/epub-import.md`                  | `lib/books/`, `lib/platform/`      |
| Metadata, spine, and TOC    | Package parsing section of `docs/epub-import.md`, `docs/data-model.md` | `lib/books/`                     |
| Canonical HTML conversion   | Canonical conversion section of `docs/epub-import.md`, `docs/data-model.md` | `lib/books/`                |
| Sentence segmentation       | Sentence segmentation section of `docs/epub-import.md`, sentence section of `docs/data-model.md` | `lib/books/` |
| EPUB import orchestration   | Import orchestration section of `docs/epub-import.md`, EPUB import section of `docs/architecture.md` | `lib/books/`, `lib/app/` |
| Source language detection   | Language detection section of `docs/epub-import.md`                 | `lib/books/`, `lib/platform/`      |
| Canonical book model        | `docs/data-model.md`, `docs/invariants.md`                           | `lib/books/`                       |
| Stable IDs and text anchors | `docs/invariants.md`, `docs/data-model.md`                           | `lib/books/`, `lib/shared/`        |
| Library UI, search, sorting, and local opening | Import orchestration section of `docs/epub-import.md`, reading state in `docs/invariants.md` | `lib/app/`, `lib/reader/` |
| Local book removal          | Storage lifecycle and repository sections of `docs/epub-import.md` | `lib/books/`, `lib/platform/`, `lib/app/` |
| Pagination                  | `docs/reader-pagination-layout.md`, pagination section of `docs/architecture.md`, derived data in `docs/data-model.md`, `docs/invariants.md` | `lib/reader/` |
| Reading position            | `docs/invariants.md`, reader section of `docs/architecture.md`       | `lib/reader/`                      |
| Highlights and notes        | `docs/invariants.md`, annotation section of `docs/data-model.md`     | `lib/reader/`                      |
| AI provider                 | Intelligence section of `docs/architecture.md`                       | `lib/intelligence/`                |
| AI context builder          | Intelligence section of `docs/architecture.md`, `docs/invariants.md` | `lib/intelligence/`                |
| Translation                 | Translation section of `docs/architecture.md`, `docs/invariants.md`  | `lib/intelligence/`, `lib/reader/` |
| Chapter overview            | Intelligence section of `docs/architecture.md`                       | `lib/intelligence/`                |
| Reader settings and layout | Reader settings section of `docs/data-model.md`, settings and persistence sections of `docs/architecture.md` | `lib/settings/`, `lib/platform/` |
| Local persistence           | Persistence section of `docs/architecture.md`, local persistence section of `docs/data-model.md` | `lib/platform/` |
| Book repository             | Repository and database section of `docs/epub-import.md`, local persistence section of `docs/data-model.md` | `lib/books/`, `lib/platform/` |
| Synchronization             | Sync section of `docs/architecture.md`, `docs/invariants.md`         | `lib/sync/`                        |
| Product clarification       | Relevant requirement inside `docs/product-plan.md`                   | Varies                             |

## Documentation roles

### `docs/flutter-guidelines/`

Contains generic Flutter and Dart implementation guidance. Read only the file
matching the task:

- `code-style.md` for language usage, code quality, dependencies, API design,
  widget composition, or lint configuration.
- `application-patterns.md` for application structure, state management,
  dependency injection, routing, serialization, logging, or code generation.
- `testing-and-documentation.md` when adding tests or documenting APIs.
- `ui-and-accessibility.md` for visual design, themes, assets, responsive
  layouts, typography, or accessibility.

These guides are generic defaults. Project-specific module boundaries,
invariants, task acceptance criteria, and existing architectural decisions take
precedence.

### `docs/product-plan.md`

Contains the complete product requirements.

Read it only when:

- The task file references a specific requirement ID.
- Acceptance criteria are ambiguous.
- Product behavior must be clarified.

Do not read it merely to implement a normal technical task.

### `docs/architecture.md`

Contains system boundaries and component interactions.

Read only the section linked by the task file.

### `docs/invariants.md`

Contains rules that must remain true across modules.

Read for tasks involving:

- Stable identifiers.
- Reading position.
- Pagination.
- Annotations.
- Translations.
- AI references.
- Synchronization.

### `docs/data-model.md`

Contains canonical persisted and in-memory models.

Read for tasks that create or change stored data.

### `docs/epub-import.md`

Contains the implemented Milestone 1 import pipeline, its feature/platform
contracts, failure cleanup, parsing stages, and focused validation guidance.

Read only the relevant section for work involving EPUB validation, storage,
package parsing, canonical conversion, sentence segmentation, import progress,
book persistence, or source-language detection.

## Source-of-truth priority

When information conflicts, use this order:

1. Assigned task acceptance criteria.
2. `docs/invariants.md`.
3. `docs/architecture.md`.
4. `docs/epub-import.md`.
5. `docs/data-model.md`.
6. `docs/product-plan.md`.
7. Relevant file under `docs/flutter-guidelines/`.
8. Existing implementation.

Do not silently resolve meaningful conflicts. Report them before implementation.

## Repository inspection rules

Start by inspecting only:

1. Files explicitly listed in the task.
2. Direct imports of those files.
3. Tests for the affected component.

Expand inspection only when a dependency or interface requires it.

Do not recursively inspect every file in `lib/`.
