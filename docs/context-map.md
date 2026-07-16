# Context Map

Use this file to locate documentation and code relevant to an assigned task.
Do not read every linked document by default.

## Always read

- `AGENTS.md`
- The assigned file under `tasks/active/`

## Read by task area

| Task area | Read | Main code location |
| --- | --- | --- |
| Architecture and progress | `docs/project-architecture-guide.md` | All layers |
| Dart and Flutter conventions | Relevant file under `docs/flutter-guidelines/` | Affected layer |
| EPUB validation and parsing | Relevant section of `docs/epub-import.md` | `lib/data/services/` |
| Canonical conversion and sentence segmentation | `docs/epub-import.md`, `docs/data-model.md` | Data services, domain use cases |
| EPUB import orchestration | Import orchestration in `docs/epub-import.md` | `ImportBookUseCase`, library ViewModel |
| Canonical book model | `docs/data-model.md`, `docs/invariants.md` | `lib/domain/models/` |
| Stable IDs and anchors | `docs/invariants.md`, `docs/data-model.md` | Domain models |
| Library UI, search, and sorting | `docs/epub-import.md`, reading-state invariants | Library ViewModel and views |
| Local book removal | Storage lifecycle in `docs/epub-import.md` | Remove-book use case, data storage |
| Pagination | `docs/reader-pagination-layout.md`, `docs/data-model.md`, `docs/invariants.md` | Pagination use case, reader UI |
| Reading position | `docs/invariants.md`, `docs/reader-pagination-layout.md` | Reader ViewModel and repositories |
| Reader selection and actions | `docs/invariants.md`, `docs/reader-pagination-layout.md` | Reader UI feature |
| Reader settings and themes | Reader settings in `docs/data-model.md` | Domain settings, reader UI, data repository |
| Local persistence | Local persistence in `docs/data-model.md` | Data repositories and services |
| In-book full-text search | Local full-text search in `docs/data-model.md`, `docs/invariants.md` | Search repository, book persistence, reader UI |
| Secure AI credentials | AI provider credentials in `docs/data-model.md`, `docs/invariants.md` | Credential repository and platform-secure data implementation |
| AI provider interface and errors | AI provider boundary in `docs/data-model.md`, `docs/invariants.md` | Domain AI models and provider port |
| AI context building | AI context package in `docs/data-model.md`, `docs/invariants.md` | Context models, local search, context use case |
| AI prompts and structured outputs | AI prompt templates in `docs/data-model.md`, relevant AI product requirement | Prompt models and registry |
| Cached AI artifacts | Cached AI result in `docs/data-model.md`, `docs/invariants.md` | AI cache model/repository and database migration |
| Highlights, notes, bookmarks, AI, translation, or sync | `docs/invariants.md`, `docs/data-model.md`, relevant product requirement | Domain model/repository, data repository, reader UI |
| Product clarification | Relevant requirement in `docs/product-plan.md` | Varies |

## Documentation roles

### `docs/project-architecture-guide.md`

The source of truth for layer responsibilities, dependency direction, MVVM,
repository ownership, dependency injection, and feature flow.

### `docs/flutter-guidelines/`

Generic implementation defaults:

- `code-style.md` for Dart APIs, quality, dependencies, and linting.
- `application-patterns.md` for MVVM, state, injection, and serialization.
- `testing-and-documentation.md` for tests and public API documentation.
- `ui-and-accessibility.md` for widgets, layouts, themes, and accessibility.

Project invariants and task acceptance criteria take precedence.

### `docs/invariants.md`

Rules that must remain true for stable identifiers, positions, pagination,
annotations, translations, intelligence references, and synchronization.

### `docs/data-model.md`

Canonical persisted and in-memory models. Read it when changing stored data or
serialization.

### `docs/epub-import.md`

The implemented EPUB pipeline, storage lifecycle, cleanup behavior, parsing
stages, and validation guidance.

### `docs/product-plan.md`

Complete product requirements. Read only when the task references a requirement
or product behavior is ambiguous.

## Source-of-truth priority

1. Assigned task acceptance criteria.
2. `docs/invariants.md`.
3. `docs/project-architecture-guide.md`.
4. `docs/epub-import.md`.
5. `docs/data-model.md`.
6. `docs/product-plan.md`.
7. Relevant Flutter guideline.
8. Existing implementation.

Do not silently resolve meaningful conflicts.

## Repository inspection

Start with files named by the task, their direct imports, and affected tests.
Expand only when an interface or dependency requires it.
