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

## EPUB import

EPUB import is a staged pipeline owned by `books` contracts and implemented by
`platform` integrations:

```text
Selected EPUB bytes
  → validate ZIP/package/spine/DRM
  → derive content-addressed book ID
  → stage unchanged original file
  → parse metadata, navigation, and spine
  → convert chapter HTML into canonical blocks
  → segment paragraph sentences
  → detect source language
  → stage extracted assets
  → commit files and persist the canonical book
```

Parsing and canonical conversion run outside the UI isolate. Cancellation or
failure before persistence rolls back staged files. If database persistence
fails after file promotion, the promoted book directory is removed.

See `docs/epub-import.md` for contracts, stable identity inputs, cleanup rules,
and implementation entry points.

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

The local database is versioned. Canonical chapter content is persisted, while
pagination remains derived and must never have a permanent `pages` table.

Book import writes its book, chapter, and chapter-content rows in one database
transaction. Database exceptions must be translated into application failures.

## Pagination

The reader paginates canonical chapter blocks in spine order using the effective
reader layout and Flutter text measurement. Text blocks may split only at
measured UTF-16 source offsets. Lists use a deterministic textual projection:
item text is source content, a newline separates each item, and visual markers
do not advance source offsets. Images are atomic source units with offsets
`0..1` and currently use the reader placeholder height.

Each temporary `PageBoundary` stores collapsed start and end-exclusive source
anchors plus its layout key. The anchors may reference different blocks when a
page spans blocks. Page indexes and layout keys remain derived navigation data;
they must not replace logical reading positions and are never persisted in a
`pages` table.

The swipeable reader paginates every canonical chapter in spine order before it
creates a finite horizontal page view. Pagination yields between chapters so
loading UI remains responsive, and stale work is discarded when the effective
viewport changes. Dragging left advances and dragging right returns; the first
and final global pages are hard bounds, while adjacent spine chapters meet at a
normal page transition. Reader chrome reports the current chapter and global
`Page X of Y` without inserting chapter titles into canonical page content.

Measurement and display share the same source-range projection and typography,
including inline styles, list projection, quote inset, and image placeholder
geometry. Text measurement is bounded to the number of lines that can plausibly
fit the viewport so pagination remains practical for long chapters. Only the
settled page's stable start anchor is sent to reading-position persistence;
temporary page numbers remain presentation state.

Reading-position writes are serialized so an older asynchronous save cannot
overwrite a newer locator. The reader starts a save immediately when the app
becomes inactive, pauses, or detaches, and awaits a final save before a normal
route close. Disposal retains a non-blocking fallback for removal outside route
navigation. Reopening loads the stored `bookId`, chapter and block IDs, UTF-16
character offset, and UTC update time, then selects the temporary page containing
that logical locator.

Reader layout preferences are loaded with canonical content before the first
pagination. The layout sheet keeps edits in a draft; Apply saves the current
locator and the device-global settings before rebuilding pagination. Font,
spacing, margin, text-scale, and viewport changes all restore the temporary page
containing that locator rather than reusing its previous page number.

Light, dark, and paper themes use reader-local Material color schemes and are
persisted in the same global preferences. Theme changes update page paint and
Android system-bar colors without invalidating page boundaries; the paper
palette uses a warm surface with a dark-brown foreground for readable contrast.

Reader table-of-contents navigation loads the canonical nested EPUB entries
from `books.toc_json` through a platform repository. Selecting an entry resolves
its chapter and optional block to a zero-offset logical locator, saves that
locator, and rebuilds the temporary reader page at the page containing it. A
chapter-only entry uses that chapter's first readable block; missing targets
show a recoverable message and leave the current position unchanged.

Word selection reuses the same display-to-source projection as pagination.
`RenderParagraph` converts the tap to a displayed character, list decorations
are rejected because they consume no source offsets, and Unicode-aware word
boundaries produce a stable `WordSelection` in one canonical block. The reader
holds one paint-only highlight at a time; its background does not change text
metrics or page boundaries.

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
