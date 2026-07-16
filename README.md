# Flow Reading

Flow Reading is a local-first Flutter Android EPUB reader. It imports EPUB files
into canonical content, paginates that content for the active reader layout,
and persists logical reading positions using stable content anchors.

## Architecture

The application uses three layers:

- `lib/domain`: immutable models, repository ports, and use cases.
- `lib/data`: SQLite, files, EPUB parsing, and platform-plugin adapters.
- `lib/ui`: MVVM ViewModels and Flutter views grouped by feature.

`lib/main.dart` is the composition root. See
`docs/project-architecture-guide.md` for dependency rules and feature flows.

## Development

```shell
flutter pub get
flutter analyze
flutter test
flutter run
```

Android is the primary target and a physical device is normally connected over
USB for smoke testing reader interactions.
