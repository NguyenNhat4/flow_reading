import 'dart:convert';

import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings round-trip every configurable field', () {
    final settings = ReaderSettings(
      fontFamily: 'Literata',
      fontSize: 21,
      lineHeight: 1.8,
      margins: ReaderMargins(left: 12, top: 20, right: 14, bottom: 22),
      theme: ReaderTheme.paper,
      orientation: ReaderOrientation.landscape,
      languageMode: ReaderLanguageMode.mixed,
    );

    final restored = ReaderSettings.fromJson(
      (jsonDecode(jsonEncode(settings.toJson())) as Map)
          .cast<String, Object?>(),
    );

    expect(restored, settings);
    expect(settings.toJson()['schemaVersion'], ReaderSettings.schemaVersion);
  });

  test('missing and unknown values use defaults', () {
    final restored = ReaderSettings.fromJson({
      'fontSize': 'large',
      'lineHeight': 10,
      'margins': {'left': -1, 'top': 30},
      'theme': 'unknown',
      'orientation': 'sideways',
      'languageMode': 'translated',
    });

    expect(restored.fontSize, ReaderSettings.defaults.fontSize);
    expect(restored.lineHeight, ReaderSettings.defaults.lineHeight);
    expect(restored.margins.left, ReaderMargins.defaults.left);
    expect(restored.margins.top, 30);
    expect(restored.theme, ReaderTheme.light);
    expect(restored.orientation, ReaderOrientation.system);
    expect(restored.languageMode, ReaderLanguageMode.original);
  });

  test('constructors validate supported numeric ranges', () {
    expect(() => ReaderSettings(fontSize: 11.9), throwsArgumentError);
    expect(() => ReaderSettings(fontSize: 36.1), throwsArgumentError);
    expect(() => ReaderSettings(lineHeight: .9), throwsArgumentError);
    expect(() => ReaderSettings(lineHeight: 2.5), throwsArgumentError);
    expect(() => ReaderMargins(left: -1), throwsArgumentError);
    expect(() => ReaderMargins(bottom: 65), throwsArgumentError);
    expect(ReaderSettings(fontSize: 12).fontSize, 12);
    expect(ReaderSettings(fontSize: 36).fontSize, 36);
  });

  test('empty font family uses the system font', () {
    expect(ReaderSettings(fontFamily: '  ').fontFamily, isNull);
  });

  test('pagination key is stable and excludes paint-only preferences', () {
    final base = ReaderLayout(
      settings: ReaderSettings(),
      viewportWidth: 400,
      viewportHeight: 800,
    );
    final same = ReaderLayout(
      settings: ReaderSettings(),
      viewportWidth: 400,
      viewportHeight: 800,
    );
    final paintOnly = ReaderLayout(
      settings: ReaderSettings(
        theme: ReaderTheme.dark,
        orientation: ReaderOrientation.landscape,
      ),
      viewportWidth: 400,
      viewportHeight: 800,
    );

    expect(same.paginationCacheKey, base.paginationCacheKey);
    expect(paintOnly.paginationCacheKey, base.paginationCacheKey);
    expect(base.paginationCacheKey, startsWith('layout_'));
  });

  test('every pagination input changes the key', () {
    String key({
      ReaderSettings? settings,
      double width = 400,
      double height = 800,
      double scale = 1,
      int version = 1,
    }) => ReaderLayout(
      settings: settings ?? ReaderSettings(),
      viewportWidth: width,
      viewportHeight: height,
      textScale: scale,
      paginationVersion: version,
    ).paginationCacheKey;

    final base = key();
    final variants = [
      key(settings: ReaderSettings(fontFamily: 'Literata')),
      key(settings: ReaderSettings(fontSize: 19)),
      key(settings: ReaderSettings(lineHeight: 1.6)),
      key(settings: ReaderSettings(margins: ReaderMargins(left: 25))),
      key(settings: ReaderSettings(languageMode: ReaderLanguageMode.mixed)),
      key(width: 401),
      key(height: 801),
      key(scale: 1.1),
      key(version: 2),
    ];

    expect(variants, everyElement(isNot(base)));
  });
}
