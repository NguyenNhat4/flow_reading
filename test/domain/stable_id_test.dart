import 'package:flow_reading/shared/domain/stable_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fingerprint = 'source-hash';

  test('IDs ignore pagination and display order', () {
    String buildId() => StableId.content(
      sourceFingerprint: fingerprint,
      type: CanonicalNodeType.paragraph,
      sourceDocumentPath: 'OPS/Text/Chapter.xhtml',
      structuralPath: const [2, 7],
    );

    final portraitPages = [
      [buildId()],
    ];
    final landscapePages = [
      ['previous-content', buildId(), 'next-content'],
    ];
    expect(portraitPages.single.single, landscapePages.single[1]);
  });

  test('duplicate text at different source positions has different IDs', () {
    final first = StableId.content(
      sourceFingerprint: fingerprint,
      type: CanonicalNodeType.paragraph,
      sourceDocumentPath: 'chapter.xhtml',
      structuralPath: const [0, 2],
    );
    final duplicate = StableId.content(
      sourceFingerprint: fingerprint,
      type: CanonicalNodeType.paragraph,
      sourceDocumentPath: 'chapter.xhtml',
      structuralPath: const [0, 3],
    );
    expect(first, isNot(duplicate));
  });

  test('normalizes equivalent EPUB paths', () {
    final windows = StableId.content(
      sourceFingerprint: fingerprint,
      type: CanonicalNodeType.chapter,
      sourceDocumentPath: r'OPS\Text\Chapter.xhtml',
      structuralPath: const [0],
    );
    final posix = StableId.content(
      sourceFingerprint: fingerprint,
      type: CanonicalNodeType.chapter,
      sourceDocumentPath: 'ops/text/chapter.xhtml',
      structuralPath: const [0],
    );
    expect(windows, posix);
  });
}
