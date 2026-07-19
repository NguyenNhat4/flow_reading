import 'dart:convert';

import 'package:flow_reading/domain/services/sha256.dart';

enum ReaderTheme { light, dark, paper }

enum ReaderOrientation { system, portrait, landscape }

enum ReaderLanguageMode { original, vietnamese, mixed }

final class ReaderMargins {
  factory ReaderMargins({
    double left = 24,
    double top = 16,
    double right = 24,
    double bottom = 16,
  }) {
    _validateRange(left, 'left', 0, 64);
    _validateRange(top, 'top', 0, 64);
    _validateRange(right, 'right', 0, 64);
    _validateRange(bottom, 'bottom', 0, 64);
    return ReaderMargins._(left, top, right, bottom);
  }

  const ReaderMargins._(this.left, this.top, this.right, this.bottom);

  static final defaults = ReaderMargins();

  final double left;
  final double top;
  final double right;
  final double bottom;

  @override
  bool operator ==(Object other) =>
      other is ReaderMargins &&
      left == other.left &&
      top == other.top &&
      right == other.right &&
      bottom == other.bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

final class ReaderSettings {
  factory ReaderSettings({
    String? fontFamily,
    double fontSize = 18,
    double lineHeight = 1.5,
    ReaderMargins? margins,
    ReaderTheme theme = ReaderTheme.light,
    ReaderOrientation orientation = ReaderOrientation.system,
    ReaderLanguageMode languageMode = ReaderLanguageMode.original,
  }) {
    _validateRange(fontSize, 'fontSize', 12, 36);
    _validateRange(lineHeight, 'lineHeight', 1, 2.4);
    final normalizedFamily = fontFamily?.trim();
    return ReaderSettings._(
      fontFamily: normalizedFamily == null || normalizedFamily.isEmpty
          ? null
          : normalizedFamily,
      fontSize: fontSize,
      lineHeight: lineHeight,
      margins: margins ?? ReaderMargins.defaults,
      theme: theme,
      orientation: orientation,
      languageMode: languageMode,
    );
  }

  const ReaderSettings._({
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.margins,
    required this.theme,
    required this.orientation,
    required this.languageMode,
  });

  static const schemaVersion = 1;
  static final defaults = ReaderSettings();

  final String? fontFamily;
  final double fontSize;
  final double lineHeight;
  final ReaderMargins margins;
  final ReaderTheme theme;
  final ReaderOrientation orientation;
  final ReaderLanguageMode languageMode;

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      fontFamily == other.fontFamily &&
      fontSize == other.fontSize &&
      lineHeight == other.lineHeight &&
      margins == other.margins &&
      theme == other.theme &&
      orientation == other.orientation &&
      languageMode == other.languageMode;

  @override
  int get hashCode => Object.hash(
    fontFamily,
    fontSize,
    lineHeight,
    margins,
    theme,
    orientation,
    languageMode,
  );
}

final class ReaderLayout {
  static const defaultPaginationVersion = 2;
  static const paginationBottomSafetyInset = 2.0;

  ReaderLayout({
    required this.settings,
    required this.viewportWidth,
    required this.viewportHeight,
    this.textScale = 1,
    this.paginationVersion = defaultPaginationVersion,
  }) {
    _validatePositive(viewportWidth, 'viewportWidth');
    _validatePositive(viewportHeight, 'viewportHeight');
    _validatePositive(textScale, 'textScale');
    if (paginationVersion < 1) {
      throw ArgumentError.value(
        paginationVersion,
        'paginationVersion',
        'must be at least 1',
      );
    }
  }

  final ReaderSettings settings;
  final double viewportWidth;
  final double viewportHeight;
  final double textScale;
  final int paginationVersion;

  double get contentWidth =>
      viewportWidth - settings.margins.left - settings.margins.right;

  double get viewportContentHeight =>
      viewportHeight - settings.margins.top - settings.margins.bottom;

  double get contentHeight =>
      viewportContentHeight - paginationBottomSafetyInset;

  String get paginationCacheKey {
    final payload = <Object?>[
      paginationVersion,
      settings.fontFamily,
      _normalized(settings.fontSize),
      _normalized(settings.lineHeight),
      _normalized(settings.margins.left),
      _normalized(settings.margins.top),
      _normalized(settings.margins.right),
      _normalized(settings.margins.bottom),
      settings.languageMode.name,
      _normalized(viewportWidth),
      _normalized(viewportHeight),
      _normalized(textScale),
    ];
    return 'layout_${sha256Hex(utf8.encode(jsonEncode(payload)))}';
  }
}

void _validateRange(double value, String name, double minimum, double maximum) {
  if (!value.isFinite || value < minimum || value > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'must be between $minimum and $maximum',
    );
  }
}

void _validatePositive(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'must be finite and greater than 0');
  }
}

String _normalized(double value) => value.toStringAsFixed(3);
