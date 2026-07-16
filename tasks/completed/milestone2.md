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

**Status:** Complete

**Priority:** P1

Remove the selected local book and all data owned by it:

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

**Status:** Complete

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
