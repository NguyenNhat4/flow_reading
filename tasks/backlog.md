# EPUB Reader Development Task List

## Priority levels

* **P0:** Required for the first working reader.
* **P1:** Required for the AI reader prototype.
* **P2:** Required for the complete MVP.
* **P3:** Later capability.

---

# Milestone 0 — Project foundation

## TASK-001 — Create Flutter project structure

**Priority:** P0

Create only these initial modules:

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

**Acceptance criteria:**

* Flutter application runs on Android.
* Portrait and landscape modes work.
* No placeholder feature folders are created.
* `flutter analyze` passes.
* A basic test runs successfully.

---

## TASK-002 — Add repository architecture rules

**Priority:** P0

Create `AGENTS.md` containing:

* Approved top-level modules.
* Stable-ID rules.
* Maximum folder-depth rules.
* File-budget rules.
* Dependency boundaries.
* Instructions against temporary report files.
* Requirement to list files before implementation.

**Acceptance criteria:**

* Agents cannot create new top-level modules without approval.
* Temporary agent notes are stored under `.agent/`.
* `.agent/` is excluded from Git unless explicitly needed.

---

## TASK-003 — Configure core dependencies

**Priority:** P0

Add only dependencies needed for:

* Local database.
* File selection.
* File-system access.
* EPUB archive reading.
* Secure storage.
* State management.
* HTTP requests.
* Connectivity detection.

**Acceptance criteria:**

* Every dependency has a documented reason.
* No duplicate libraries provide the same capability.
* No synchronization or authentication SDK is added yet.

---

## TASK-004 — Create shared error model

**Priority:** P0

Create application failures for:

* Invalid EPUB.
* Unsupported DRM.
* File-system failure.
* Database failure.
* Network failure.
* Invalid API key.
* AI provider failure.

**Acceptance criteria:**

* UI code does not inspect raw database or HTTP exceptions.
* Every failure has a readable user-facing message.

---

# Milestone 1 — Canonical EPUB import

## TASK-101 — Define canonical book models

**Priority:** P0

Implement:

```text
Book
BookMetadata
Chapter
ChapterReference
ContentBlock
ParagraphBlock
HeadingBlock
ImageBlock
ListBlock
BookSentence
BookAsset
TableOfContentsEntry
```

**Acceptance criteria:**

* Models do not contain visual page numbers.
* Chapters preserve EPUB reading order.
* Blocks preserve meaningful formatting.
* Models can be serialized and restored.

---

## TASK-102 — Define stable content identifiers

**Priority:** P0

Implement deterministic identifiers for:

* Books.
* Chapters.
* Blocks.
* Sentences.
* Text ranges.

**Acceptance criteria:**

* Importing the same unchanged EPUB twice generates the same content IDs.
* IDs do not depend on screen size, font size, or page number.
* Text selections can be represented using stable IDs and character offsets.

---

## TASK-103 — Implement text-anchor model

**Priority:** P0

Create:

```text
TextAnchor
ReadingLocator
WordSelection
PassageSelection
```

A text anchor must contain:

* Book ID.
* Chapter ID.
* Block ID.
* Start offset.
* End offset.

**Acceptance criteria:**

* The same passage can be found after repagination.
* Anchors can be serialized into the local database.
* Invalid offset ranges are rejected.

---

## TASK-104 — Implement EPUB validation

**Priority:** P0

Validate:

* ZIP structure.
* EPUB mimetype.
* Package document.
* Spine.
* Chapter resources.
* Unsupported encryption or DRM.

**Acceptance criteria:**

* Valid EPUB files continue to parsing.
* Corrupted files produce a readable error.
* Unsupported DRM produces a specific error.
* Failed imports do not affect existing books.

---

## TASK-105 — Preserve original EPUB

**Priority:** P0

Copy the imported EPUB into application-controlled storage.

**Acceptance criteria:**

* The source file is never modified.
* The copied file is associated with its book ID.
* Duplicate files can be detected using a content hash.
* A failed import removes its incomplete copied data.

---

## TASK-106 — Parse EPUB metadata and table of contents

**Priority:** P0

Extract:

* Title.
* Author.
* Cover.
* Language metadata.
* Spine order.
* Table of contents.
* Chapter titles.

**Acceptance criteria:**

* Missing optional metadata does not break import.
* Chapter order follows the EPUB spine.
* Table-of-contents entries navigate to stable chapter references.

---

## TASK-107 — Convert EPUB HTML into canonical blocks

**Priority:** P0

Convert chapter content into:

* Headings.
* Paragraphs.
* Lists.
* Quotes.
* Images.
* Basic inline formatting.

**Acceptance criteria:**

* Unsafe or unsupported HTML is removed.
* Text order remains correct.
* Images reference local extracted assets.
* Simple and complex EPUB samples can be imported.

---

## TASK-108 — Implement sentence segmentation

**Priority:** P0

Split paragraph text into sentences while preserving:

* Original text.
* Character offsets.
* Sentence order.
* Stable sentence IDs.

**Acceptance criteria:**

* Common English punctuation works.
* Common Vietnamese punctuation works.
* Abbreviations do not cause obvious incorrect splitting.
* Original paragraph text can be reconstructed.

---

## TASK-109 — Create local database schema

**Priority:** P0

Create tables for:

```text
books
chapters
chapter_content
reading_states
annotations
bookmarks
notes
ai_artifacts
chat_sessions
chat_messages
glossary_terms
reader_preferences
sync_outbox
```

**Acceptance criteria:**

* Schema migrations are versioned.
* Chapter content can be stored and loaded.
* A database failure does not corrupt previously imported books.
* No permanent `pages` table is created.

---

## TASK-110 — Implement book repository

**Priority:** P0

Support:

* Save imported book.
* List books.
* Read book metadata.
* Load chapters.
* Delete books.
* Detect duplicates.

**Acceptance criteria:**

* Import persistence uses a transaction.
* Partial imports are rolled back.
* Repository methods expose application failures, not database exceptions.

---

## TASK-111 — Add import progress reporting

**Priority:** P1

Report stages such as:

```text
Validating file
Reading metadata
Parsing chapters
Extracting images
Saving book
Building search index
Complete
```

**Acceptance criteria:**

* The UI remains responsive.
* Large imports can be cancelled safely.
* Cancellation removes incomplete data.

---

## TASK-112 — Detect source language

**Priority:** P1

Detect the primary language after import.

**Acceptance criteria:**

* The detected language is stored with the book.
* The user can confirm or correct it.
* Failure to detect a language does not block reading.

---

# Milestone 2 — Local library

## TASK-201 — Build library screen

**Priority:** P0

Display:

* Cover.
* Title.
* Author.
* Reading progress.
* Last-opened time.

**Acceptance criteria:**

* Imported books appear immediately.
* Empty-library state explains how to import a book.
* Books can be opened without an account.

---

## TASK-202 — Add EPUB file picker

**Priority:** P0

Allow the user to select an EPUB from Android storage.

**Acceptance criteria:**

* Only supported files are accepted.
* Selection begins the import flow.
* Cancelling selection leaves the library unchanged.

---

## TASK-203 — Implement remove-book flow

**Priority:** P1

Allow users to choose whether to delete:

* Original EPUB.
* Parsed content.
* Reading state.
* Highlights and notes.
* Translations.
* AI conversations.

**Acceptance criteria:**

* Confirmation is required.
* Deleting one book does not affect another book.
* File and database cleanup remain consistent.

---

## TASK-204 — Add library search and sorting

**Priority:** P2

Support searching and sorting by:

* Title.
* Author.
* Recent activity.
* Reading progress.
* Import date.

**Acceptance criteria:**

* Search works without internet.
* Search responds correctly with a moderately sized library.

---

# Milestone 3 — Reader foundation

## TASK-301 — Implement reader layout model

**Priority:** P0

Create configurable settings for:

* Font family.
* Font size.
* Line height.
* Margins.
* Theme.
* Orientation.
* Language mode.

**Acceptance criteria:**

* Settings are serializable.
* Settings can be stored per user or globally.
* Layout configuration can generate a pagination-cache key.

---

## TASK-302 — Implement pagination engine

**Priority:** P0

Convert canonical chapter blocks into temporary page boundaries.

**Acceptance criteria:**

* Pages fit the available viewport.
* Text order remains correct.
* Page boundaries reference stable source anchors.
* Pagination results are not treated as permanent book data.

---

## TASK-303 — Build swipeable reader

**Priority:** P0

Implement:

* Swipe left for next page.
* Swipe right for previous page.
* Chapter transitions.
* Basic page indicator.

**Acceptance criteria:**

* Swiping feels responsive.
* The reader cannot move outside the book boundaries.
* Chapter navigation follows spine order.

---

## TASK-304 — Save logical reading position

**Priority:** P0

Save position using:

```text
bookId
chapterId
blockId
characterOffset
updatedAt
```

**Acceptance criteria:**

* Position is saved when the application enters the background.
* Position is saved when the book closes.
* Reopening the book restores the same logical passage.

---

## TASK-305 — Preserve position after repagination

**Priority:** P0

When the user changes layout:

1. Save the current locator.
2. Recalculate pagination.
3. Find the page containing the locator.
4. Open that page.

**Acceptance criteria:**

* Changing font size does not jump to an unrelated passage.
* Rotating the device preserves the logical position.
* Changing margins and spacing preserves the logical position.

---

## TASK-306 — Add reader themes

**Priority:** P1

Implement:

* Light.
* Dark.
* Paper-like.

**Acceptance criteria:**

* Text remains readable in all themes.
* Theme selection persists after restart.
* System bars visually match the selected theme.

---

## TASK-307 — Add table-of-contents navigation

**Priority:** P1

**Acceptance criteria:**

* The table of contents opens inside the reader.
* Selecting an entry navigates to the correct chapter or anchor.
* Navigation updates reading state.

---

## TASK-308 — Implement word selection

**Priority:** P1

Allow users to tap a word.

**Acceptance criteria:**

* The selected word maps to a stable text range.
* Selection remains visually visible while actions are shown.
* Punctuation is not incorrectly included where avoidable.

---

## TASK-309 — Implement passage selection

**Priority:** P1

Allow long-press selection of a sentence or passage.

**Acceptance criteria:**

* Start and end offsets map to canonical content.
* The user can adjust the selected range.
* Selection can cross sentence boundaries where supported.

---

## TASK-310 — Create reader action menu

**Priority:** P1

Word actions:

```text
Define
Ask AI
Translate
Highlight
Copy
```

Passage actions:

```text
Explain
Ask AI
Translate
Summarize
Explain Grammar
Highlight
Copy
```

**Acceptance criteria:**

* Offline-only actions remain usable offline.
* Online actions clearly indicate when connectivity is required.
* Opening an action does not lose the reading position.

---

# Milestone 4 — Annotations and search

## TASK-401 — Implement highlights

**Priority:** P1

**Acceptance criteria:**

* Highlights attach to text anchors.
* Highlights survive font-size changes.
* Highlights survive orientation changes.
* Highlights are visible after reopening the book.

---

## TASK-402 — Implement notes

**Priority:** P2

**Acceptance criteria:**

* A note can be attached to a selected passage.
* Notes can be edited and deleted.
* Selecting a note returns to its passage.

---

## TASK-403 — Implement bookmarks

**Priority:** P2

**Acceptance criteria:**

* Bookmarks use logical reading locators.
* Bookmarks can be listed and removed.
* Opening a bookmark navigates to the correct passage.

---

## TASK-404 — Implement local full-text search index

**Priority:** P2

Index searchable segments containing:

```text
segmentId
bookId
chapterId
blockId
plainText
```

**Acceptance criteria:**

* Search works offline.
* Results display surrounding text.
* Selecting a result returns to the correct location.

---

# Milestone 5 — AI foundation

## TASK-501 — Implement secure API-key storage

**Priority:** P1

**Acceptance criteria:**

* API keys use Android-protected credential storage.
* Keys are never stored in logs.
* Keys are never stored in the normal database.
* No developer-owned API key exists in the application.

---

## TASK-502 — Define AI provider interface

**Priority:** P1

Create one common interface for:

* Key validation.
* Completion.
* Streaming.
* Provider error mapping.

**Acceptance criteria:**

* UI code does not depend on a provider SDK.
* Product prompts do not live inside provider implementations.
* Only one provider is implemented initially.

---

## TASK-503 — Implement first AI provider

**Priority:** P1

**Acceptance criteria:**

* A valid key can be verified.
* Invalid keys produce `InvalidApiKeyFailure`.
* Rate limits and connectivity errors are handled.
* Streaming requests can be cancelled.

---

## TASK-504 — Implement context builder

**Priority:** P1

Build an AI context package containing:

* Selected text.
* Containing sentence.
* Containing paragraph.
* Nearby paragraphs.
* Chapter title.
* Current position.
* Relevant earlier passages.
* Recent conversation messages.

**Acceptance criteria:**

* Context respects a maximum size budget.
* Selected text has highest priority.
* Duplicate passages are removed.
* Every included passage retains its stable anchor.

---

## TASK-505 — Implement prompt templates

**Priority:** P1

Create versioned prompts for:

* Word explanation.
* Passage explanation.
* Grammar explanation.
* Summary.
* Translation.
* Chapter overview.
* Chat.

**Acceptance criteria:**

* Every prompt has a version number.
* Prompts require the model to distinguish facts from interpretation.
* Prompts request structured output where useful.

---

## TASK-506 — Implement AI artifact cache

**Priority:** P1

Cache:

* Explanations.
* Translations.
* Chapter overviews.
* Summaries.

**Acceptance criteria:**

* Cache keys include content hash and prompt version.
* Cached responses are available offline.
* Changing a prompt version does not silently reuse incompatible output.

---

## TASK-507 — Add word explanation

**Priority:** P1

Return:

* Contextual meaning.
* Part of speech.
* Reason it is used in the passage.
* Simpler paraphrase.
* At least two examples.
* Ambiguity warning where needed.

**Acceptance criteria:**

* Response is grounded in the selected sentence.
* The user remains on the reader screen.
* The result is cached locally.

---

## TASK-508 — Add passage explanation

**Priority:** P1

**Acceptance criteria:**

* The passage remains visible while loading.
* The request can be cancelled.
* The explanation preserves the original meaning.
* Failed requests provide Retry.

---

## TASK-509 — Add grammar explanation

**Priority:** P2

**Acceptance criteria:**

* Only grammar relevant to understanding the passage is explained.
* The response does not become a generic grammar lesson.
* Results are cached.

---

# Milestone 6 — Contextual chatbot

## TASK-601 — Build assistant bottom sheet

**Priority:** P1

Open the assistant without navigating away from the reader.

**Acceptance criteria:**

* The visible passage remains accessible.
* The sheet can be expanded and collapsed.
* Closing the sheet returns to the same reading position.

---

## TASK-602 — Create book-aware chat sessions

**Priority:** P1

Associate each chat with:

* Book ID.
* Optional chapter ID.
* Current reading context.
* Message history.

**Acceptance criteria:**

* Recent messages are available to the context builder.
* Conversation history can be restored.
* Conversations do not mix content from different books.

---

## TASK-603 — Update chat context while reading

**Priority:** P1

**Acceptance criteria:**

* Moving to another chapter updates active context.
* Existing conversation messages remain available.
* The chatbot knows the currently visible passage.

---

## TASK-604 — Add passage backlinks

**Priority:** P2

**Acceptance criteria:**

* Responses can reference stable passage anchors.
* Tapping a reference navigates to the cited passage.
* References remain valid after repagination.

---

# Milestone 7 — Translation

## TASK-701 — Define translation model

**Priority:** P1

Associate each translation with:

* Source sentence ID.
* Target language.
* Translated text.
* Provider and model.
* Prompt version.
* Creation time.

**Acceptance criteria:**

* Translation remains linked to the source sentence.
* Translations do not create a separate translated-book hierarchy.

---

## TASK-702 — Implement sentence translation

**Priority:** P1

**Acceptance criteria:**

* Surrounding paragraph context is included.
* Source tone and intent are requested.
* Translation is cached locally.
* Vietnamese is the initial target language.

---

## TASK-703 — Implement Original mode

**Priority:** P1

**Acceptance criteria:**

* Only source content is displayed.
* No AI translation is required.
* Reading remains fully available offline.

---

## TASK-704 — Implement VN mode

**Priority:** P1

**Acceptance criteria:**

* Vietnamese translation replaces source text where available.
* Missing offline translation falls back to original text.
* Missing translation state is clearly explained.

---

## TASK-705 — Implement MIX mode

**Priority:** P1

**Acceptance criteria:**

* Every source sentence is followed by its translation.
* Sentence pairs remain correctly associated.
* Layout remains readable.

---

## TASK-706 — Preserve position between language modes

**Priority:** P1

**Acceptance criteria:**

* The user remains near the same source sentence.
* Switching modes triggers safe repagination.
* Highlights and notes remain attached to source anchors.

---

## TASK-707 — Implement per-book glossary

**Priority:** P2

**Acceptance criteria:**

* Glossary entries are associated with a book.
* Established terminology is included in later translation requests.
* Users can inspect and edit glossary terms.

---

# Milestone 8 — Chapter overview

## TASK-801 — Detect chapter boundaries

**Priority:** P1

**Acceptance criteria:**

* Spine-based chapters are identified.
* Unreliable boundaries produce an explicit fallback.
* The user can select a section manually when needed.

---

## TASK-802 — Generate chapter overview

**Priority:** P1

Include:

* Big picture.
* Main ideas or events.
* Important concepts.
* Chapter structure.
* What to pay attention to.

**Acceptance criteria:**

* The complete chapter is analyzed within provider limits.
* Large chapters are processed safely in segments.
* The overview clearly warns about content ahead.

---

## TASK-803 — Cache chapter overview

**Priority:** P1

**Acceptance criteria:**

* Cached overview loads offline.
* Regeneration requires an explicit action.
* Cache invalidates when chapter content or prompt version changes.

---

# Milestone 9 — Offline behavior and resilience

## TASK-901 — Implement connectivity state

**Priority:** P1

**Acceptance criteria:**

* Reading never depends on connectivity.
* Online-only actions show a clear offline message.
* Losing connectivity does not change the reading position.

---

## TASK-902 — Implement retry and cancellation

**Priority:** P1

**Acceptance criteria:**

* AI requests can be cancelled.
* Failed requests show Retry.
* Cancelling does not create a successful cache record.
* Duplicate retry requests are prevented.

---

## TASK-903 — Add local cache management

**Priority:** P2

**Acceptance criteria:**

* Users can inspect cache storage size.
* AI cache can be cleared without deleting books.
* Book deletion can optionally clear associated artifacts.

---

# Milestone 10 — Optional synchronization

## TASK-1001 — Define syncable record metadata

**Priority:** P2

Add:

```text
id
updatedAt
deviceId
version
deletedAt
```

**Acceptance criteria:**

* Progress, annotations, notes, and preferences can be versioned.
* Pagination results are explicitly excluded from synchronization.

---

## TASK-1002 — Implement sync outbox

**Priority:** P2

**Acceptance criteria:**

* Local changes are committed before upload.
* Failed uploads remain queued.
* Duplicate operations are safely handled.

---

## TASK-1003 — Add optional authentication

**Priority:** P2

**Acceptance criteria:**

* Local reading does not require authentication.
* Authentication is introduced only when sync is enabled.
* Signing out does not delete local books.

---

## TASK-1004 — Synchronize reading state

**Priority:** P2

**Acceptance criteria:**

* Logical reading locators are synchronized.
* Most recently updated reading position wins.
* Annotations are preserved.

---

## TASK-1005 — Synchronize annotations and notes

**Priority:** P2

**Acceptance criteria:**

* Highlights and bookmarks merge by stable ID.
* Conflicting note versions are both preserved.
* Users can resolve note conflicts.

---

## TASK-1006 — Synchronize original EPUB files

**Priority:** P2

**Acceptance criteria:**

* Book synchronization is optional.
* Files are compared using a content hash.
* Cloud deletion requires confirmation.
* Local files remain when synchronization is disabled.

---

# Milestone 11 — Testing and release preparation

## TASK-1101 — Add canonical-model unit tests

**Priority:** P0

Test:

* Stable IDs.
* Sentence offsets.
* Serialization.
* Chapter ordering.
* Text anchors.

---

## TASK-1102 — Add import integration tests

**Priority:** P0

Test:

* Valid EPUB.
* Corrupted EPUB.
* Missing metadata.
* Unsupported DRM.
* Complex chapter structure.
* Failed-import rollback.

---

## TASK-1103 — Add reader integration tests

**Priority:** P0

Test:

* Open and restore position.
* Font-size repagination.
* Rotation.
* Chapter transitions.
* Highlight preservation.

---

## TASK-1104 — Add AI integration tests

**Priority:** P1

Test:

* Valid API key.
* Invalid API key.
* Offline request.
* Rate limit.
* Retry.
* Cancellation.
* Cache hit.

---

## TASK-1105 — Add translation-mode tests

**Priority:** P1

Test:

* Original to VN.
* VN to MIX.
* Missing offline translation.
* Position preservation.
* Annotation preservation.

---

## TASK-1106 — Test low- and mid-range Android devices

**Priority:** P2

Measure:

* EPUB import duration.
* Pagination duration.
* Memory usage.
* Chapter-opening speed.
* Reader swipe smoothness.
* Large-book behavior.

---

## TASK-1107 — Add privacy controls

**Priority:** P2

**Acceptance criteria:**

* Users know selected book text is sent to their chosen AI provider.
* API keys are never logged.
* AI conversations can be deleted.
* Synchronized data can be deleted.
* Account deletion is available when accounts are introduced.

---

# Recommended first development sprint

Complete these tasks first:

```text
TASK-001  Project structure
TASK-002  Architecture rules
TASK-003  Core dependencies
TASK-004  Error model
TASK-101  Canonical models
TASK-102  Stable identifiers
TASK-103  Text anchors
TASK-104  EPUB validation
TASK-105  Preserve original EPUB
TASK-106  Metadata and table of contents
TASK-107  Canonical HTML conversion
TASK-108  Sentence segmentation
TASK-109  Database schema
TASK-110  Book repository
TASK-201  Library screen
TASK-202  File picker
```

## First sprint completion definition

The sprint is complete when:

1. The user can select an unprotected EPUB.
2. The application safely copies and validates it.
3. Metadata, chapters, blocks, and sentences are extracted.
4. Stable identifiers are generated.
5. The canonical book is stored locally.
6. The imported book appears in the library.
7. Closing and reopening the application preserves the library.
8. No pagination or AI implementation has been added prematurely.
