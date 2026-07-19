import 'dart:typed_data';

import 'package:flow_reading/domain/models/book_models.dart';

/// Raw package metadata extracted before canonical HTML conversion.
final class EpubChapterDraft {
  const EpubChapterDraft({
    required this.id,
    required this.sourceHref,
    required this.title,
    required this.order,
    required this.mediaType,
  });

  final String id;
  final String sourceHref;
  final String title;
  final int order;
  final String mediaType;
}

final class EpubAssetDraft {
  const EpubAssetDraft({
    required this.id,
    required this.sourceHref,
    required this.mediaType,
    required this.bytes,
  });

  final String id;
  final String sourceHref;
  final String mediaType;
  final Uint8List bytes;
}

final class EpubImportDraft {
  EpubImportDraft({
    required this.bookId,
    required this.metadata,
    required List<EpubChapterDraft> chapters,
    required List<TableOfContentsEntry> tableOfContents,
    this.cover,
  }) : chapters = List.unmodifiable(chapters),
       tableOfContents = List.unmodifiable(tableOfContents);

  final String bookId;
  final BookMetadata metadata;
  final List<EpubChapterDraft> chapters;
  final List<TableOfContentsEntry> tableOfContents;
  final EpubAssetDraft? cover;
}
