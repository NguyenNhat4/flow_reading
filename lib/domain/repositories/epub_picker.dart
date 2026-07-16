import 'dart:typed_data';

/// An EPUB selected by the user.
final class SelectedEpub {
  const SelectedEpub({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Selects an EPUB without exposing a platform plugin to presentation code.
abstract interface class EpubPicker {
  Future<SelectedEpub?> pick();
}
