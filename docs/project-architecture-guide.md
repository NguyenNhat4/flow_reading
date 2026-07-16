# Flow Reading Architecture Guide

Flow Reading uses three application layers: domain, data, and UI. Dependencies
point inward toward the domain so local reading behavior can be tested without
Flutter widgets, SQLite, files, or platform plugins.

## Project structure

```text
lib/
├── main.dart
├── data/
│   ├── models/
│   ├── repositories/
│   └── services/
├── domain/
│   ├── models/
│   ├── repositories/
│   └── use_cases/
└── ui/
    ├── app/
    ├── core/
    └── features/
        ├── library/
        │   ├── view_models/
        │   └── views/
        └── reader/
            ├── view_models/
            └── views/
```

Do not add another top-level application folder without approval.

## Layer responsibilities

### Domain

The domain contains Flutter-independent application concepts and rules:

- Canonical books, chapters, content blocks, assets, and navigation entries.
- Stable identifiers, text anchors, selections, and reading positions.
- Reader settings and temporary pagination boundaries.
- Repository and platform-port interfaces.
- Import, removal, language detection, pagination, and segmentation use cases.
- Typed application failures.

Domain code must not import Flutter, data implementations, SQLite, file-system
classes, or platform plugins.

### Data

The data layer implements domain ports and owns external integrations:

- SQLite database and repository implementations.
- Local EPUB and asset file storage.
- File-picker and ML Kit adapters.
- EPUB ZIP, XML, and HTML parsing.
- Serialization required by persistence.

Data may depend on domain. It must not import UI code. Repositories translate
integration failures into domain failures and return domain models.

### UI

The UI layer uses MVVM:

- Views render state, collect user input, show navigation and transient UI, and
  forward commands to ViewModels.
- ViewModels extend `ChangeNotifier`, expose immutable snapshots or read-only
  values, and depend only on domain interfaces and use cases.
- `ui/core` contains shared presentation concerns such as reader themes.
- `ui/app` contains the root widget and presentation dependency aggregate.

Feature views must not import concrete data implementations.

## Dependency wiring

`main.dart` is the composition root and the only normal location that imports
both concrete data implementations and UI. It creates services, repositories,
and use cases, then passes domain-facing dependencies to `FlowReadingApp`.

Use manual constructor injection. Do not add a service locator or state
management package unless a task explicitly requires one.

```text
main
  → data services and repository implementations
  → domain repository interfaces and use cases
  → UI ViewModels
  → UI views
```

## Feature flows

### EPUB import

```text
LibraryView
  → LibraryViewModel
  → ImportBookUseCase
  → EpubContentParser + BookFileStorage + BookRepository
  → concrete data services and repositories
```

Parsing runs outside the UI isolate. Cancellation or failure rolls back staged
files, and a database failure after file promotion removes the promoted book.

### Reading

```text
ReaderView
  → ReaderViewModel
  → domain repositories
  → SQLite repository implementations
```

The ViewModel loads canonical chapters, settings, position, and table of
contents; serializes position writes; resolves stable navigation targets; and
preserves logical position during repagination. Flutter-specific measurement
stays in reader presentation code, while pagination rules stay in the domain.

## Persistence invariants

- SQLite is the local source of truth.
- Existing table and JSON formats remain backward-compatible.
- Canonical content and logical positions are persisted.
- Temporary pages and page indexes are never permanent book data.
- Stable identifiers and UTF-16 text offsets must not be replaced by UI state.

## Adding a feature

1. Define or reuse immutable domain models.
2. Add domain repository ports for external operations.
3. Implement data services and repositories.
4. Add a use case only for complex or reused business logic.
5. Add a `ChangeNotifier` ViewModel with constructor-injected domain
   dependencies.
6. Build lean views with `ListenableBuilder`.
7. Wire dependencies in `main.dart` and `ui/app`.
8. Add domain, data, ViewModel, widget, and architecture tests as applicable.
