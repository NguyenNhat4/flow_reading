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
