import 'dart:typed_data';

import 'package:flow_reading/domain/models/book_models.dart';

final class CanonicalAsset {
  const CanonicalAsset({required this.asset, required this.bytes});

  final BookAsset asset;
  final Uint8List bytes;
}

final class CanonicalEpubContent {
  CanonicalEpubContent({
    required List<Chapter> chapters,
    required List<TableOfContentsEntry> tableOfContents,
    required List<CanonicalAsset> assets,
  }) : chapters = List.unmodifiable(chapters),
       tableOfContents = List.unmodifiable(tableOfContents),
       assets = List.unmodifiable(assets);

  final List<Chapter> chapters;
  final List<TableOfContentsEntry> tableOfContents;
  final List<CanonicalAsset> assets;
}
