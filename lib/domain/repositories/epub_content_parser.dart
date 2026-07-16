import 'dart:typed_data';

import 'package:flow_reading/domain/models/parsed_epub_content.dart';

/// Converts external EPUB bytes into canonical domain content.
abstract interface class EpubContentParser {
  Future<ParsedEpubContent> parse({
    required Uint8List bytes,
    required String fileName,
    required String bookId,
  });
}
