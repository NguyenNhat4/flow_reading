# Flow Reading

An Android-first, offline EPUB reader built with Flutter. The foundation keeps
canonical book content, stable reading locators, and all personal reading data on
device without requiring an account or network connection.

Milestone 1 is complete: users can import and validate unprotected EPUBs,
confirm the detected source language, search and sort the local library, read
native swipeable pages, change typography and reading themes, resume after a
restart, navigate a nested table of contents, select/copy text, and save stable
local highlights. AI-backed selection actions remain clearly unavailable until
Milestone 2 configuration is implemented.

## Development

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

The import test fixtures are generated in memory and cover valid,
missing-metadata, image-heavy, nested-TOC, RTL/Unicode, malformed, and DRM-marked
EPUBs without including copyrighted book content.

Optional compile-time configuration:

```sh
flutter run --dart-define=APP_FLAVOR=development --dart-define=LOG_LEVEL=INFO
```

### Android build compatibility

The project intentionally pins `file_picker` to `12.0.0-beta.7`. Flutter 3.44
uses Android Gradle Plugin (AGP) 9, while `file_picker` 11.0.2 can leave its
Kotlin Android implementation uncompiled when the project uses Flutter's legacy
Kotlin compatibility mode. The pinned prerelease includes the AGP 9 plugin
registration fix.

Keep `android.builtInKotlin=false` and `android.newDsl=false` in
`android/gradle.properties` until every Android plugin in the dependency graph
supports AGP's Built-in Kotlin mode. If Android reports that
`FilePickerPlugin` cannot be found, refresh the resolved plugins and rebuild:

```sh
flutter clean
flutter pub get
flutter build apk --debug
```

Replace the prerelease pin with a stable `file_picker` 12 release only after
that stable release contains the same AGP 9 fix and the debug APK build passes.

See [architecture](docs/architecture.md), [dependency decisions](docs/dependencies.md),
and [persistence](docs/persistence.md).
