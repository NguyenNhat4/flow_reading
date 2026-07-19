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
