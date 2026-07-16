
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
