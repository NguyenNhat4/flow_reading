# Architecture

Flow Reading is an offline-first Flutter application released initially for
Android phones. Portrait and landscape are first-class layouts. Local import and
reading have no account, API-key, or connectivity dependency.

## Boundaries

Code is grouped by product feature under `lib/features`: `library`, `import`,
`reader`, `annotations`, `ai`, `translation`, and `sync`. Cross-feature code is
split into `shared/domain`, `shared/data`, and `shared/ui`. Application startup,
routing, and composition live under `lib/app`; configuration and logging live
under `lib/core`.

Dependencies point inward:

```text
feature presentation -> feature use cases -> shared domain contracts
shared data adapters ---------------------> shared domain contracts
app composition -------- constructs and injects concrete adapters
```

- Riverpod is both the dependency-injection composition mechanism and UI state
  holder. Providers expose repository interfaces, not SQLite types.
- GoRouter owns app navigation and stable route names.
- Domain objects use explicit JSON serialization and version fields. No database
  or EPUB package appears in the domain layer.
- The logger emits small JSON events and redacts known sensitive field names.
  Book content, keys, selections, and notes must never be passed as log messages.
- Environment values use `--dart-define=APP_FLAVOR=...` and
  `--dart-define=LOG_LEVEL=...`. API keys are intentionally unsupported here.

## Runtime states

Every feature presents loading, empty, error, and offline states where they are
applicable. The library exposes empty, importing, failed-import, duplicate, and
missing-source states. The reader handles loading, missing-book, missing-source,
and local rendering errors without discarding its saved logical locator.
Online-only selection actions wrap only the requested action and never block the
offline reader.

The Milestone 1 importer validates bounded ZIP input, EPUB mimetype and
container metadata, the OPF manifest/spine, and unsupported encryption before a
single atomic repository commit. It rejects traversal paths, strips executable
or embedded markup and event attributes, and converts only allowlisted native
text formatting and local images into the canonical model. Language detection
is an injected offline heuristic whose result is confirmed or corrected before
commit.

Pagination measures canonical blocks against the current Flutter viewport and
reader typography. A page is disposable view state; page turns, repagination,
TOC jumps, highlights, and process restoration continue to use canonical
locators.

## Stable identity

Canonical IDs are SHA-256-derived from the source EPUB fingerprint, normalized
source document path, node type, structural ordinal path, and ID algorithm
version. Rendered pages and text are excluded. Duplicate passages therefore get
different IDs, while font, margin, viewport, orientation, and pagination changes
cannot change an ID.

A `ReadingLocator` contains a stable content ID plus character and word offsets,
affinity, format version, and migration version. Position, selection, annotation,
translation, and AI citations all use this locator rather than page numbers.
