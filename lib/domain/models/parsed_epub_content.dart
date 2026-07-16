import 'dart:typed_data';

import 'package:flow_reading/domain/models/book_models.dart';

/// Canonical content produced from a validated EPUB before persistence.
final class ParsedEpubContent {
  const ParsedEpubContent({
    required this.metadata,
    required this.chapters,
    required this.tableOfContents,
    required this.assets,
  });

  final BookMetadata metadata;
  final List<Chapter> chapters;
  final List<TableOfContentsEntry> tableOfContents;
  final List<ParsedEpubAsset> assets;
}

/// An extracted canonical asset and its original bytes.
final class ParsedEpubAsset {
  const ParsedEpubAsset({required this.asset, required this.bytes});

  final BookAsset asset;
  final Uint8List bytes;
}
