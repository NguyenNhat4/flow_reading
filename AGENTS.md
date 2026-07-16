# Project

Local-first Flutter Android EPUB reader with optional contextual AI features.

The application imports EPUB files into canonical content, paginates that
content for reading, and attaches state and future intelligence artifacts to
stable content identifiers. A physical Android device is normally connected
through USB.

## Start here

For each task:

1. Read the assigned task under `tasks/active/`.
2. Read `docs/context-map.md` to locate relevant references.
3. Use the relevant skill for the task.

## Approved application structure

Application code belongs under:

- `lib/domain/` for Flutter-independent models, repository ports, and use cases.
- `lib/data/` for repository implementations and external services.
- `lib/ui/` for app composition types, ViewModels, themes, and views.

Do not add another top-level application folder without approval.

## Dependency rules

- Domain must not import data, UI, Flutter, SQLite, files, or plugins.
- Data may import domain but must not import UI.
- UI feature code may import domain but not concrete data implementations.
- `lib/main.dart` is the composition root and may import all layers.
- Views render state and delegate commands; ViewModels own presentation logic.
- Use manual constructor dependency injection.
- Preserve stable IDs, canonical text offsets, persisted schemas, and
  local-first behavior.
