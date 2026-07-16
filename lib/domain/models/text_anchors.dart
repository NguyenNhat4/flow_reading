import 'package:flow_reading/domain/models/content_identifiers.dart';

typedef JsonMap = Map<String, Object?>;

/// A stable, layout-independent range within one canonical content block.
final class TextAnchor extends StableTextRange {
  TextAnchor({
    required super.bookId,
    required super.chapterId,
    required super.blockId,
    required super.startOffset,
    required super.endOffset,
  });

  factory TextAnchor.fromJson(JsonMap json) => TextAnchor(
    bookId: json['bookId'] as String,
    chapterId: json['chapterId'] as String,
    blockId: json['blockId'] as String,
    startOffset: json['startOffset'] as int,
    endOffset: json['endOffset'] as int,
  );
}

/// The canonical source location used to restore a reader position.
final class ReadingLocator {
  const ReadingLocator({required this.anchor});

  final TextAnchor anchor;

  JsonMap toJson() => {'anchor': anchor.toJson()};

  factory ReadingLocator.fromJson(JsonMap json) =>
      ReadingLocator(anchor: TextAnchor.fromJson(_map(json['anchor'])));
}

/// A selected word and its stable canonical source range.
final class WordSelection {
  const WordSelection({required this.anchor, required this.textSnapshot});

  final TextAnchor anchor;
  final String textSnapshot;

  JsonMap toJson() => {'anchor': anchor.toJson(), 'textSnapshot': textSnapshot};

  factory WordSelection.fromJson(JsonMap json) => WordSelection(
    anchor: TextAnchor.fromJson(_map(json['anchor'])),
    textSnapshot: json['textSnapshot'] as String,
  );
}

/// A selected passage and its stable canonical source range.
final class PassageSelection {
  const PassageSelection({required this.anchor, required this.textSnapshot});

  final TextAnchor anchor;
  final String textSnapshot;

  JsonMap toJson() => {'anchor': anchor.toJson(), 'textSnapshot': textSnapshot};

  factory PassageSelection.fromJson(JsonMap json) => PassageSelection(
    anchor: TextAnchor.fromJson(_map(json['anchor'])),
    textSnapshot: json['textSnapshot'] as String,
  );
}

JsonMap _map(Object? value) => (value as Map).cast<String, Object?>();
