# Data Model

## Core Principles
- **Permanent Source vs. Temporary Pages:** Canonical source content is permanent. Visual pages are temporary.
- **Anchors over Pages:** Never use visual page numbers for durable state (reading positions, annotations, bookmarks). Always use stable logical positions like `TextAnchor` (half-open UTF-16 source offsets) or `ReadingLocator`.
- **Derived Data:** Pagination (`PageBoundary`) is temporary in-memory data derived from layout settings (excluding color/theme). It can be safely discarded and rebuilt.

## Hierarchy & Stable Identity
- **Content Hierarchy:** `Book` > `Chapter` > `Block` > `Paragraph` > `Sentence` > `Word/Text range`
- **Deterministic Identifiers:** Do not use layout values for IDs.
  - *Book ID:* SHA-256 of unchanged EPUB bytes.
  - *Chapter ID:* Book ID + spine index + normalized source href.
  - *Block ID:* Chapter ID + canonical order/type + deterministic DOM locator.
  - *Asset ID:* Book ID + normalized source href.

## Local Persistence
- **Canonical Content:** Metadata (`books`), spine (`chapters`), and JSON content (`chapter_content`) are stored separately from user state.
- **Search (v2):** Uses a local inverted index (`search_segments`, `search_terms`) updated transactionally on import.
- **Annotations:** Bookmarks, notes, and highlights use stable anchors. Highlight saving is idempotent (based on exact source range).
- **Reader Settings:** Device-global record. Missing/malformed prefs fall back to defaults to ensure reading remains available.

## AI & Third-Party
- **Secure Credentials:** Provider keys live in secure storage (e.g., `flutter_secure_storage`). **Never** store in SQLite, logs, UI state, or book exports.
- **Provider Boundary:** `AiProviderRequest` receives rendered instructions and models, but never credentials.
- **Caching (`AiCacheEntry`):** AI artifacts use strict deterministic keys (content hash + context fingerprint + prompt version + model + source range) so changes prevent silent output reuse.
- **Context Handling:** `AiContextPackage` separates explicit facts, context, and selected text, keeping selected text first and merging duplicates.
