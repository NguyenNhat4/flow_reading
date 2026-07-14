# Flow Reading

An Android-first, offline EPUB reader built with Flutter. The foundation keeps
canonical book content, stable reading locators, and all personal reading data on
device without requiring an account or network connection.

## Development

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Optional compile-time configuration:

```sh
flutter run --dart-define=APP_FLAVOR=development --dart-define=LOG_LEVEL=INFO
```

See [architecture](docs/architecture.md), [dependency decisions](docs/dependencies.md),
and [persistence](docs/persistence.md).
