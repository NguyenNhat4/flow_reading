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
