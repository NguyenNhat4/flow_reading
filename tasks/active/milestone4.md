# Milestone 4 — Annotations and search

## TASK-401 — Implement highlights

**Status:** Complete

**Priority:** P1

**Acceptance criteria:**

* Highlights attach to text anchors.
* Highlights survive font-size changes.
* Highlights survive orientation changes.
* Highlights are visible after reopening the book.

---

## TASK-402 — Implement notes

**Status:** Complete

**Priority:** P2

**Acceptance criteria:**

* A note can be attached to a selected passage.
* Notes can be edited and deleted.
* Selecting a note returns to its passage.

---

## TASK-403 — Implement bookmarks

**Status:** Complete

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
