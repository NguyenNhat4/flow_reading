# Architecture

## Goal

Build a local-first Flutter EPUB reader with optional AI and translation features.

Detailed behavior belongs in task files and `product-plan.md`.

## Modules

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

Do not create new top-level modules without approval.

## Responsibilities

### `app`

- Application startup
- Navigation
- Dependency wiring
- App-level configuration

### `platform`

Concrete integrations:

- Database
- File picker
- File system
- Secure storage
- HTTP
- Connectivity
- EPUB libraries

### `books`

- EPUB import
- Canonical book model
- Chapters and content
- Stable content IDs
- Book repository contracts

### `reader`

- Pagination
- Page rendering
- Reading position
- Selection
- Table of contents
- Annotations
- In-book search

### `intelligence`

- AI provider interface
- Context builder
- Word and passage explanation
- Reader chat
- Chapter overview
- Translation
- Generated-content cache

### `settings`

- Reader preferences
- Theme and typography
- Reading mode
- AI provider configuration metadata

### `shared`

Only concepts used by multiple modules:

- IDs
- Failures
- Result types
- Small shared primitives

Do not use shared as a general utility folder.

## Dependency rules

```text
app → all modules
reader → books, settings, shared
intelligence → books, reader contracts, settings, shared
books → shared
settings → shared
platform → implements feature interfaces
```

Rules:

- `books` must not depend on `reader` or `intelligence`.
- `reader` must not depend on `intelligence`.
- Feature modules must not call platform plugins directly.
- UI must not access database or HTTP clients directly.
- Circular dependencies are forbidden.

## Main flow

```text
EPUB
  ↓
Import and parse
  ↓
Canonical book model
  ↓
Local persistence
  ↓
Pagination
  ↓
Reader
```

Optional intelligence flow:

```text
Reader action
  ↓
Context builder
  ↓
AI provider interface
  ↓
Provider adapter
  ↓
Cached result
  ↓
Persistence
```

## Persistence

Feature modules define repository interfaces.

Concrete implementations belong in platform.

Examples:

- `BookRepository`
- `ReadingPositionRepository`
- `AnnotationRepository`
- `TranslationRepository`
- `SettingsRepository`
- `AiResponseCache`

## Implementation order

```text
Foundation
→ EPUB import
→ Canonical model
→ Persistence
→ Pagination
→ Reading position
→ Selection and annotations
→ AI
→ Translation
→ Optional sync
```

Do not bypass unfinished foundations.
