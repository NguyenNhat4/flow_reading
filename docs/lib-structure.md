# Codebase Structure (`lib/`)

The application follows a best pratice architecture defined in flutter-apply-architecture-best-practices 

## Core Files & Folders

- `lib/main.dart`: The entry point of the application. Handles top-level provider initialization.
- `lib/app/`:
  - `app_composition.dart`: Dependency injection and provider setup.
  - `flow_reading_app.dart`: The root `MaterialApp` widget and global routing.

## Layers

The rest of the application is strictly divided into three architectural layers. Please consult the corresponding files below for detailed file-level descriptions.

- **Domain Layer**: [lib-domain-structure.md](lib-domain-structure.md)
  - Contains immutable models, repository interfaces, and use cases. No dependencies on UI or Data.
- **Data Layer**: [lib-data-structure.md](lib-data-structure.md)
  - Contains concrete repository implementations, SQLite storage, file parsing, and API adapters.
- **UI Layer**: [lib-ui-structure.md](lib-ui-structure.md)
  - Contains Flutter widgets, core styling, and ViewModels (MVVM) grouped by feature.

*Note for Agents: If you add, remove, or change the purpose of any file in the `lib/` directory, you MUST update these structure markdown files to keep them accurate.*
