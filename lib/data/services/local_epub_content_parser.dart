import 'dart:isolate';
import 'dart:typed_data';

import 'package:flow_reading/data/services/canonical_html_converter.dart';
import 'package:flow_reading/data/services/epub_package_parser.dart';
import 'package:flow_reading/data/services/epub_validator.dart';
import 'package:flow_reading/domain/models/parsed_epub_content.dart';
import 'package:flow_reading/domain/repositories/epub_content_parser.dart';

/// Parses EPUB archives outside the UI isolate.
final class LocalEpubContentParser implements EpubContentParser {
  const LocalEpubContentParser();

  @override
  Future<ParsedEpubContent> parse({
    required Uint8List bytes,
    required String fileName,
    required String bookId,
  }) => Isolate.run(() {
    final validated = EpubValidator.validate(bytes);
    final draft = EpubPackageParser.parse(
      validated,
      bookId: bookId,
      sourceFileName: fileName,
    );
    final content = CanonicalHtmlConverter.convert(
      validated,
      draft,
      assetLocalPath: (assetId, sourceHref) => '',
    );
    return ParsedEpubContent(
      metadata: draft.metadata,
      chapters: content.chapters,
      tableOfContents: content.tableOfContents,
      assets: [
        for (final asset in content.assets)
          ParsedEpubAsset(asset: asset.asset, bytes: asset.bytes),
      ],
    );
  });
}
