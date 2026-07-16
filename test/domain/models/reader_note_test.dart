import 'dart:convert';

import 'package:flow_reading/domain/models/reader_note.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes and serializes a note with range-derived identity', () {
    final note = ReaderNote(
      range: _range,
      body: '  Remember this.  ',
      createdAt: DateTime.utc(2026, 2, 1),
      updatedAt: DateTime.utc(2026, 2, 2),
    );

    final restored = ReaderNote.fromJson(
      (jsonDecode(jsonEncode(note.toJson())) as Map).cast<String, Object?>(),
    );

    expect(note.id, _range.id);
    expect(restored.body, 'Remember this.');
    expect(restored.updatedAt, DateTime.utc(2026, 2, 2));
  });

  test('rejects empty note text', () {
    expect(
      () => ReaderNote(
        range: _range,
        body: '  ',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
  });
}

final _range = TextAnchor(
  bookId: 'book',
  chapterId: 'chapter',
  blockId: 'block',
  startOffset: 0,
  endOffset: 7,
);
