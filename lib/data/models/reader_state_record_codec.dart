import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';

/// Encodes durable reader state using the current SQLite JSON field contract.
final class ReaderStateRecordCodec {
  const ReaderStateRecordCodec._();

  static Map<String, Object?> encodeAnchor(TextAnchor value) => value.toJson();

  static TextAnchor decodeAnchor(Map<String, Object?> value) =>
      TextAnchor.fromJson(value);

  static Map<String, Object?> encodeLocator(ReadingLocator value) =>
      value.toJson();

  static ReadingLocator decodeLocator(Map<String, Object?> value) =>
      ReadingLocator.fromJson(value);

  static Map<String, Object?> encodeSettings(ReaderSettings value) => {
    'schemaVersion': ReaderSettings.schemaVersion,
    'fontFamily': value.fontFamily,
    'fontSize': value.fontSize,
    'lineHeight': value.lineHeight,
    'margins': {
      'left': value.margins.left,
      'top': value.margins.top,
      'right': value.margins.right,
      'bottom': value.margins.bottom,
    },
    'theme': value.theme.name,
    'orientation': value.orientation.name,
    'languageMode': value.languageMode.name,
  };

  static ReaderSettings decodeSettings(Map<String, Object?> value) {
    final margins = value['margins'];
    final defaults = ReaderSettings.defaults;
    return ReaderSettings(
      fontFamily: value['fontFamily'] is String
          ? value['fontFamily'] as String
          : null,
      fontSize: _validDouble(value['fontSize'], 12, 36) ?? defaults.fontSize,
      lineHeight:
          _validDouble(value['lineHeight'], 1, 2.4) ?? defaults.lineHeight,
      margins: margins is Map
          ? _decodeMargins(margins.cast<String, Object?>())
          : ReaderMargins.defaults,
      theme: _enumValue(ReaderTheme.values, value['theme']) ?? defaults.theme,
      orientation:
          _enumValue(ReaderOrientation.values, value['orientation']) ??
          defaults.orientation,
      languageMode:
          _enumValue(ReaderLanguageMode.values, value['languageMode']) ??
          defaults.languageMode,
    );
  }

  static ReaderMargins _decodeMargins(
    Map<String, Object?> value,
  ) => ReaderMargins(
    left: _validDouble(value['left'], 0, 64) ?? ReaderMargins.defaults.left,
    top: _validDouble(value['top'], 0, 64) ?? ReaderMargins.defaults.top,
    right: _validDouble(value['right'], 0, 64) ?? ReaderMargins.defaults.right,
    bottom:
        _validDouble(value['bottom'], 0, 64) ?? ReaderMargins.defaults.bottom,
  );
}

T? _enumValue<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  return values.where((value) => value.name == name).firstOrNull;
}

double? _validDouble(Object? value, double minimum, double maximum) {
  if (value is! num) return null;
  final converted = value.toDouble();
  return converted.isFinite && converted >= minimum && converted <= maximum
      ? converted
      : null;
}
