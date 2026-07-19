# EPUB Reader Task Backlog & Index

This file acts as the high-level reference for all milestones and tasks in the project. Task files are organized into three folders:
* Completed milestones/tasks: `tasks/completed/`
* Currently active milestones: `tasks/active/`
* Remaining milestones: `tasks/backlog/`

---

## Milestone 0 — Project foundation
**Status:** Completed
* [TASK-001 — Create Flutter project structure](completed/TASK-001-create-flutter-project-structure.md) (P0)
* [TASK-002 — Add repository architecture rules](completed/TASK-002-add-repository-architecture-rules.md) (P0)
* [TASK-003 — Configure core dependencies](completed/TASK-003-configure-core-dependencies.md) (P0)
* [TASK-004 — Create shared error model](completed/TASK-004-create-shared-error-model.md) (P0)

## Milestone 1 — Canonical EPUB import
**Status:** Completed
* File: [milestone1.md](completed/milestone1.md)
* Tasks:
  * TASK-101 — Define canonical book models (P0)
  * TASK-102 — Define stable content identifiers (P0)
  * TASK-103 — Implement text-anchor model (P0)
  * TASK-104 — Implement EPUB validation (P0)
  * TASK-105 — Preserve original EPUB (P0)
  * TASK-106 — Parse EPUB metadata and table of contents (P0)
  * TASK-107 — Convert EPUB HTML into canonical blocks (P0)
  * TASK-108 — Implement sentence segmentation (P0)
  * TASK-109 — Create local database schema (P0)
  * TASK-110 — Implement book repository (P0)
  * TASK-111 — Add import progress reporting (P1)
  * TASK-112 — Detect source language (P1)

## Milestone 2 — Local library
**Status:** Completed
* File: [milestone2.md](completed/milestone2.md)
* Tasks:
  * TASK-201 — Build library screen (P0)
  * TASK-202 — Add EPUB file picker (P0)
  * TASK-203 — Implement remove-book flow (P1)
  * TASK-204 — Add library search and sorting (P2)

## Milestone 3 — Reader foundation
**Status:** Completed
* File: [milestone3.md](completed/milestone3.md)
* Tasks:
  * TASK-301 — Implement reader layout model (P0)
  * TASK-302 — Implement pagination engine (P0)
  * TASK-303 — Build swipeable reader (P0)
  * TASK-304 — Save logical reading position (P0)
  * TASK-305 — Preserve position after repagination (P0)
  * TASK-306 — Add reader themes (P1)
  * TASK-307 — Add table-of-contents navigation (P1)
  * TASK-308 — Implement word selection (P1)
  * TASK-309 — Implement passage selection (P1)
  * TASK-310 — Create reader action menu (P1)

## Milestone 4 — Annotations and search
**Status:** Completed
* File: [milestone4.md](completed/milestone4.md)
* Tasks:
  * TASK-401 — Implement highlights (P1)
  * TASK-402 — Implement notes (P2)
  * TASK-403 — Implement bookmarks (P2)
  * TASK-404 — Implement local full-text search index (P2)

## Milestone 5 — AI foundation
**Status:** Active
* File: [milestone5.md](active/milestone5.md)
* Tasks:
  * TASK-501 — Implement secure API-key storage (P1)
  * TASK-502 — Define AI provider interface (P1)
  * TASK-503 — Implement first AI provider (P1)
  * TASK-504 — Implement context builder (P1)
  * TASK-505 — Implement prompt templates (P1)
  * TASK-506 — Implement AI artifact cache (P1)
  * TASK-507 — Add word explanation (P1)
  * TASK-508 — Add passage explanation (P1)
  * TASK-509 — Add grammar explanation (P2)

## Milestone 6 — Contextual chatbot
**Status:** Backlog
* File: [milestone6.md](backlog/milestone6.md)
* Tasks:
  * TASK-601 — Build assistant bottom sheet (P1)
  * TASK-602 — Create book-aware chat sessions (P1)
  * TASK-603 — Update chat context while reading (P1)
  * TASK-604 — Add passage backlinks (P2)

## Milestone 7 — Translation
**Status:** Backlog
* File: [milestone7.md](backlog/milestone7.md)
* Tasks:
  * TASK-701 — Define translation model (P1)
  * TASK-702 — Implement sentence translation (P1)
  * TASK-703 — Implement Original mode (P1)
  * TASK-704 — Implement VN mode (P1)
  * TASK-705 — Implement MIX mode (P1)
  * TASK-706 — Preserve position between language modes (P1)
  * TASK-707 — Implement per-book glossary (P2)

## Milestone 8 — Chapter overview
**Status:** Backlog
* File: [milestone8.md](backlog/milestone8.md)
* Tasks:
  * TASK-801 — Detect chapter boundaries (P1)
  * TASK-802 — Generate chapter overview (P1)
  * TASK-803 — Cache chapter overview (P1)

## Milestone 9 — Offline behavior and resilience
**Status:** Backlog
* File: [milestone9.md](backlog/milestone9.md)
* Tasks:
  * TASK-901 — Implement connectivity state (P1)
  * TASK-902 — Implement retry and cancellation (P1)
  * TASK-903 — Add local cache management (P2)

## Milestone 10 — Optional synchronization
**Status:** Backlog
* File: [milestone10.md](backlog/milestone10.md)
* Tasks:
  * TASK-1001 — Define syncable record metadata (P2)
  * TASK-1002 — Implement sync outbox (P2)
  * TASK-1003 — Add optional authentication (P2)
  * TASK-1004 — Synchronize reading state (P2)
  * TASK-1005 — Synchronize annotations and notes (P2)
  * TASK-1006 — Synchronize original EPUB files (P2)

## Milestone 11 — Testing and release preparation
**Status:** Backlog
* File: [milestone11.md](backlog/milestone11.md)
* Tasks:
  * TASK-1101 — Add canonical-model unit tests (P0)
  * TASK-1102 — Add import integration tests (P0)
  * TASK-1103 — Add reader integration tests (P0)
  * TASK-1104 — Add AI integration tests (P1)
  * TASK-1105 — Add translation-mode tests (P1)
  * TASK-1106 — Test low- and mid-range Android devices (P2)
  * TASK-1107 — Add privacy controls (P2)
