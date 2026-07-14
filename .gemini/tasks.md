# Flow Reading implementation tasks

This backlog turns `requirements.md` into dependency-ordered implementation work for the current Flutter starter project. Complete tasks in order unless a task explicitly says it can run in parallel. Requirement IDs in parentheses provide traceability.

## Definition of done for every implementation task

- [ ] Production code, loading/empty/error/offline states, and accessibility semantics are implemented.
- [ ] Unit, widget, or integration tests cover the main path and important failures.
- [ ] `flutter analyze` and `flutter test` pass.
- [ ] Persistent-data changes include a migration or a documented reset strategy during prototyping.
- [ ] No API keys, copyrighted book content, or personal reading data are written to logs.

## Milestone 0 — Foundation and architecture

### 0.1 Establish the application structure

- [ ] Replace the Flutter counter starter with the Flow Reading app shell.
- [ ] Organize code by feature (`library`, `import`, `reader`, `annotations`, `ai`, `translation`, `sync`) with shared domain, data, and UI layers.
- [ ] Add routing, dependency injection, state management, structured logging, and environment configuration.
- [ ] Configure Android as the initial supported release target and verify portrait/landscape behavior. (PLAT-001, PLAT-002)
- [ ] Add CI commands for formatting, static analysis, unit/widget tests, and Android debug builds.

### 0.2 Select and document core technical dependencies

- [ ] Evaluate and record choices for EPUB parsing, HTML/CSS rendering, local SQL/full-text search, file picking, secure storage, connectivity, networking, and serialization.
- [ ] Document package licenses, Android compatibility, maintenance risk, and why each package was selected.
- [ ] Add only the dependencies required for Milestone 1 to `pubspec.yaml`.

### 0.3 Define the canonical book model first

- [ ] Model book metadata, table of contents, chapters, blocks, paragraphs, sentences, words, images, formatting, annotations, glossary, chapter overview, and reading state.
- [ ] Define deterministic stable IDs for chapters, paragraphs, sentences, and words; IDs must survive app restarts and repagination. (BOOK-008, READ-008, AI-006)
- [ ] Define a logical reading locator using stable content ID plus character/word offset, with migration/version fields.
- [ ] Define repositories so domain logic is independent of the database and EPUB parser.
- [ ] Add serialization and round-trip tests, including reordered pagination and duplicate text cases.

### 0.4 Create the local persistence layer

- [ ] Design tables and indexes for books, canonical content, reading state, annotations, cached AI results, translations, glossary entries, conversations, and pending sync operations.
- [ ] Add transactions for atomic import and deletion.
- [ ] Store the untouched source EPUB in app-private storage and reference it from the book record. (BOOK-007)
- [ ] Verify all local reading data remains accessible without an account and without connectivity. (PLAT-003, LIB-001, SYNC-001)

## Milestone 1 — Canonical EPUB reader prototype

### 1.1 Build the EPUB import pipeline

- [ ] Add an Android file-picker flow restricted to EPUB candidates.
- [ ] Validate the ZIP/container structure, package document, content manifest, and unsupported DRM before committing any data. (BOOK-001, BOOK-005, BOOK-006)
- [ ] Extract metadata, cover, table of contents, chapters, paragraphs, sentences, words, images, supported formatting, and reading order. (BOOK-002)
- [ ] Sanitize imported markup and prevent external scripts or unsafe file access.
- [ ] Generate canonical stable IDs and persist the complete model in one atomic operation.
- [ ] Preserve the original EPUB byte-for-byte and detect duplicate imports. (BOOK-007)
- [ ] Show import progress and readable errors; a failed import must not alter existing books.
- [ ] Add fixtures/tests for valid, malformed, missing-metadata, image-heavy, nested-TOC, RTL/Unicode, and DRM-marked EPUBs.

### 1.2 Implement source-language detection

- [ ] Detect a primary language from representative book text during import and save its confidence/source. (BOOK-003, LANG-001)
- [ ] Let the user confirm or correct the detected language. (BOOK-004)
- [ ] Keep the detection service replaceable so a future offline implementation can be introduced.

### 1.3 Build the local library

- [ ] Display cover, title, author, reading progress, and last-opened time for every imported book. (LIB-002)
- [ ] Open a selected book at its latest logical reading locator. (LIB-003)
- [ ] Implement library search and sorting by title, author, recent activity, and progress. (LIB-006)
- [ ] Add empty, importing, failed-import, and missing-source-file states.
- [ ] Confirm before removing a book. (LIB-004)
- [ ] On removal, let the user independently retain or delete notes, highlights, translations, and AI conversations. (LIB-005)

### 1.4 Implement pagination and navigation

- [ ] Build a pagination engine for canonical reflowable content using the available viewport and reader settings. (READ-001)
- [ ] Render supported text styles, headings, lists, links, and inline/block images without requiring fixed EPUB page layout.
- [ ] Add horizontal page gestures: swipe left for next and right for previous, with sensible first/last-page behavior. (READ-002, READ-003)
- [ ] Add table-of-contents navigation and a lightweight position/progress indicator. (READ-006)
- [ ] Save reading position on page changes, app backgrounding, and app close. (READ-007)
- [ ] Restore the logical position after process death and app restart.
- [ ] Test pagination with small/large screens and portrait/landscape orientations.

### 1.5 Add reader customization and stable repagination

- [ ] Add font family, font size, line spacing, margins, and orientation-aware layout controls.
- [ ] Add light, dark, and paper-like themes. (READ-005)
- [ ] Repaginate after settings or orientation changes while preserving the logical reading position. (READ-004)
- [ ] Confirm annotations and contextual references remain attached to stable content IDs after every repagination. (READ-008)
- [ ] Add performance tests for opening, paginating, and repaginating representative large chapters.

### 1.6 Implement text selection primitives

- [ ] Resolve a tap to a canonical word ID and show Define, Ask AI, Translate, Highlight, and Copy. (WORD-001, WORD-002)
- [ ] Support long-press selection of a sentence or longer passage across rendered spans/pages. (PASS-001)
- [ ] Show Explain, Ask AI, Translate, Summarize, Explain Grammar, Highlight, and Copy. (PASS-002)
- [ ] Preserve selection as stable start/end locators so it survives repagination.
- [ ] Implement Copy and local Highlight now; route AI-dependent actions to a clear setup/offline state until Milestone 2.

### Milestone 1 exit criteria

- [ ] A user can import an unprotected EPUB, browse it in the library, read it as swipeable pages offline, customize the display, restart at the saved position, and select text.
- [ ] Stable-locator tests prove that position and highlights survive font, margin, theme, and orientation changes.

## Milestone 2 — Context-aware AI prototype

### 2.1 Add provider-independent AI infrastructure

- [ ] Define a common provider adapter for validation, chat/completion requests, streaming/cancellation, normalized errors, usage metadata, and future providers. (AI-011)
- [ ] Add provider/model/base-URL settings without shipping a developer-owned key. (AI-001, AI-004)
- [ ] Store user keys only in Android protected credential storage and redact them everywhere else. (AI-003)
- [ ] Validate a saved key before enabling AI actions. (AI-002)
- [ ] If a provider rejects a key, disable new requests and guide the user to update it without interrupting reading. (AI-009)

### 2.2 Build the book-context service

- [ ] Assemble selected text, containing sentence/paragraph, nearby paragraphs, chapter metadata, reading locator, relevant earlier passages, and recent conversation messages. (AI-005)
- [ ] Implement local full-text search/retrieval over canonical content for relevant earlier passages.
- [ ] Enforce configurable context/token limits and deterministic truncation that prioritizes the selected and nearby text.
- [ ] Reference every context item and response citation with stable content IDs.
- [ ] Add tests ensuring content from a different book or private key data can never enter a request.

### 2.3 Implement word and passage assistance

- [ ] Generate a contextual definition rather than an unfiltered list. (WORD-003)
- [ ] For Ask AI on a word, return contextual meaning, part of speech, passage-specific usage, a simpler paraphrase, and at least two examples. (WORD-004)
- [ ] Explicitly describe ambiguity when multiple meanings are plausible. (WORD-005)
- [ ] Explain selected passages in simpler language while preserving meaning. (PASS-003)
- [ ] Explain only grammar relevant to understanding the selection. (PASS-004)
- [ ] Label claims that are interpretation rather than explicit author statements. (AI-007)
- [ ] Keep selected text visible; run requests in a non-blocking panel and support cancellation while reading continues. (PASS-005)

### 2.4 Add resilient requests and offline cache

- [ ] Cache successful AI results locally using provider/model/prompt-version/context IDs as cache inputs. (AI-008)
- [ ] Load cached responses while offline.
- [ ] On request failure, preserve reading position and selection, explain the error, and offer Retry. (PLAT-004, AI-010)
- [ ] Do not mark failed/cancelled requests as successful or count them in local usage totals.
- [ ] Add timeouts, cancellation, bounded retry behavior, and tests for offline, rate-limit, auth, timeout, malformed-response, and provider-error cases.

### 2.5 Build the in-reader chatbot

- [ ] Open the assistant as an overlay/bottom sheet without leaving the book. (CHAT-001)
- [ ] Seed it with current book, chapter, locator, and visible passage context. (CHAT-002)
- [ ] Update active context when the reader moves while chat stays open. (CHAT-003)
- [ ] Support natural-language questions without manual copying and retain relevant conversation context. (CHAT-004, CHAT-006)
- [ ] Attach tappable stable-locator links to answers relying on specific passages. (CHAT-005)
- [ ] Let the user opt in to saving a conversation associated with the current book. (CHAT-007)

### Milestone 2 exit criteria

- [ ] With a valid user-owned key, word help, passage help, and chatbot answers use book context, can be cancelled/retried, and cache successfully for later offline viewing.
- [ ] Removing or invalidating the key never prevents local reading.

## Milestone 3 — Translation and chapter intelligence

### 3.1 Implement chapter overviews

- [ ] Show Chapter Overview at reliably detected chapter beginnings. (CHAP-001)
- [ ] Analyze the complete chapter and produce the big picture, main ideas/events, concepts/terminology, structure, and points to watch. (CHAP-002, CHAP-003)
- [ ] Display a clear content-ahead/spoiler notice before showing or generating an overview. (CHAP-004)
- [ ] Cache and reuse an overview unless the user explicitly regenerates it. (CHAP-005)
- [ ] If chapter boundaries are unreliable, ask the user to choose a section. (CHAP-006)

### 3.2 Build contextual translation services

- [ ] Add Vietnamese as the initial translation target. (LANG-002)
- [ ] Translate using paragraph/chapter context, established terminology, and writing style. (LANG-007)
- [ ] Prompt and evaluate for preservation of author tone, voice, and intent. (LANG-008)
- [ ] Create and maintain a per-book terminology glossary; apply confirmed terms consistently. (LANG-009)
- [ ] Cache translations by stable content ID, source revision, target language, glossary revision, provider/model, and prompt version. (LANG-011)

### 3.3 Implement Original, VN, and MIX reading modes

- [ ] Original mode displays untouched source text without AI translation. (LANG-003, LANG-004)
- [ ] VN mode replaces source sentences with Vietnamese translations. (LANG-005)
- [ ] MIX mode displays each original sentence followed by its Vietnamese translation. (LANG-006)
- [ ] Preserve the logical reading position when switching modes and when different text lengths trigger repagination. (LANG-010)
- [ ] Display cached translations offline. (LANG-012)
- [ ] If uncached translation is requested offline, keep the original visible and explain why translation is unavailable. (LANG-013)

### Milestone 3 exit criteria

- [ ] A user can view cached chapter overviews and switch among Original, VN, and MIX without losing position; translation remains terminology-aware and has explicit offline behavior.

## Milestone 4 — Complete MVP

### 4.1 Finish reading tools

- [ ] Add bookmarks linked to stable locators.
- [ ] Complete highlight creation/editing/deletion and color support.
- [ ] Add notes linked to stable selections.
- [ ] Add in-book full-text search with results that navigate to the passage. (READ-006)
- [ ] Add management views for bookmarks, highlights, and notes.

### 4.2 Add optional accounts and synchronization

- [ ] Add optional authentication; never gate local import or reading behind an account. (SYNC-001, SYNC-002)
- [ ] Define versioned sync records, device IDs, timestamps, tombstones, encryption/transport protections, and a pending-operation queue.
- [ ] Sync reading progress, bookmarks, highlights, notes, and preferences when enabled. (SYNC-003)
- [ ] Offer separate opt-in synchronization of original EPUB files through protected cloud storage. (SYNC-004)
- [ ] Queue mutations offline and synchronize when connectivity returns. (SYNC-005, SYNC-006)
- [ ] Resolve progress conflicts using the most recently updated position without losing annotations. (SYNC-007)
- [ ] Preserve both conflicting note versions until the user resolves them. (SYNC-008)
- [ ] When sync is disabled, retain local books and reading data. (SYNC-009)
- [ ] After confirmation, delete synchronized personal data and cloud books when account deletion is requested. (SYNC-010)
- [ ] Add multi-device integration tests for offline edits, retries, duplicates, deletions, and conflicts.

### 4.3 Privacy, reliability, and observability

- [ ] Add clear controls for AI data sharing, saved conversations, cache deletion, sync scope, book-file uploads, and account deletion.
- [ ] Document what text is sent to an AI provider and when.
- [ ] Add crash/performance monitoring with no book content, API keys, or personal annotations in telemetry.
- [ ] Test database migration, storage exhaustion, interrupted import, corrupt cache, process death, and upgrade recovery.
- [ ] Audit screen-reader labels, touch target sizes, contrast, text scaling, and keyboard/switch navigation where Android supports it.

### Milestone 4 exit criteria

- [ ] All requirements PLAT-001 through SYNC-010 are implemented or explicitly documented as an approved exception.
- [ ] Core local reading works with no account, no API key, and no network.
- [ ] Sync and cloud book upload are separate, explicit opt-ins and have verified deletion paths.

## Milestone 5 — Play Store beta

### 5.1 Verification and release readiness

- [ ] Build a legally distributable EPUB fixture set covering simple, complex, malformed, image-heavy, long, and multilingual books.
- [ ] Run unit, widget, integration, golden, accessibility, migration, offline, and end-to-end tests.
- [ ] Measure import time, page-turn latency, repagination time, memory, battery, storage, and crash-free sessions on low- and mid-range Android phones.
- [ ] Verify portrait/landscape lifecycle behavior and background position saving on supported Android versions.
- [ ] Complete threat modeling and security review for EPUB parsing, WebView/rendering, file storage, API keys, AI requests, authentication, sync, and deletion.
- [ ] Conduct closed testing and triage release-blocking feedback.

### 5.2 Store and production rollout

- [ ] Publish a privacy policy matching actual AI, telemetry, account, and sync behavior.
- [ ] Complete the Play Data safety declaration and account-deletion disclosures.
- [ ] Prepare localized listing copy, screenshots, app icon, feature graphic, and support contact.
- [ ] Configure package ID, versioning, signing, release obfuscation/symbol upload, and a signed Android App Bundle.
- [ ] Use staged rollout with crash/performance thresholds and a rollback/kill-switch plan for online features.

## Deferred backlog — Post-MVP

- [ ] Import text-based PDFs into the canonical model.
- [ ] Add OCR for scanned PDFs and images.
- [ ] Add offline dictionary and language detection.
- [ ] Evaluate offline translation and a small on-device model for basic explanations.
- [ ] Optimize UI and pagination for tablets and foldables.
- [ ] Add translation targets beyond Vietnamese.
- [ ] Evaluate iOS, web, and desktop only after Android product validation.
- [ ] Keep book marketplace, audiobooks, social features, DRM circumvention, and perfect fixed-layout reproduction out of scope unless product requirements change.

## Suggested first implementation slice

- [ ] Complete 0.1–0.4.
- [ ] Import one known-good, unprotected EPUB into the canonical model.
- [ ] Render one chapter as swipeable pages using stable logical locators.
- [ ] Prove a saved position survives font-size change, orientation change, and app restart.
- [ ] Do not begin AI integration until this slice and its tests pass.
