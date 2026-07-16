import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flow_reading/data/services/android_epub_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'returns the selected EPUB bytes without a native extension filter',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final picker = AndroidEpubPicker(
        () async =>
            PlatformFile(name: 'Book.EPUB', size: bytes.length, bytes: bytes),
      );

      final selected = await picker.pick();

      expect(selected?.name, 'Book.EPUB');
      expect(selected?.bytes, bytes);
    },
  );

  test('returns null when the native picker is canceled', () async {
    final picker = AndroidEpubPicker(() async => null);

    expect(await picker.pick(), isNull);
  });

  test('rejects a selected file without an EPUB extension', () async {
    final picker = AndroidEpubPicker(
      () async => PlatformFile(name: 'notes.pdf', size: 0, bytes: Uint8List(0)),
    );

    await expectLater(
      picker.pick(),
      throwsA(
        isA<EpubPickerException>().having(
          (error) => error.message,
          'message',
          'Select a file whose name ends with .epub.',
        ),
      ),
    );
  });
}
