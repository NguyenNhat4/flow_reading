import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

final class SelectedEpub {
  const SelectedEpub({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

final class EpubPickerException implements Exception {
  const EpubPickerException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef PlatformFilePicker = Future<PlatformFile?> Function();

final class AndroidEpubPicker {
  AndroidEpubPicker([PlatformFilePicker? picker]) : _picker = picker ?? _pick;

  final PlatformFilePicker _picker;

  Future<SelectedEpub?> pick() async {
    final file = await _picker();
    if (file == null) return null;
    if (!file.name.toLowerCase().endsWith('.epub')) {
      throw const EpubPickerException(
        'Select a file whose name ends with .epub.',
      );
    }
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      throw const EpubPickerException('The selected EPUB could not be read.');
    }
    return SelectedEpub(name: file.name, bytes: bytes);
  }

  static Future<PlatformFile?> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    return result?.files.single;
  }
}
