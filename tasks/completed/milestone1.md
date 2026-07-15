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

## TASK-111 — 

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
Add import progress reporting