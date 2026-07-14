import 'package:flow_reading/shared/domain/book.dart';
import 'package:flow_reading/shared/domain/stable_id.dart';

Book sampleBook({String sourcePath = 'incoming.epub'}) {
  const fingerprint =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final chapterId = StableId.content(
    sourceFingerprint: fingerprint,
    type: CanonicalNodeType.chapter,
    sourceDocumentPath: 'Text/chapter1.xhtml',
    structuralPath: const [0],
  );
  final paragraphId = StableId.content(
    sourceFingerprint: fingerprint,
    type: CanonicalNodeType.paragraph,
    sourceDocumentPath: 'Text/chapter1.xhtml',
    structuralPath: const [0, 0],
  );
  final sentenceId = StableId.content(
    sourceFingerprint: fingerprint,
    type: CanonicalNodeType.sentence,
    sourceDocumentPath: 'Text/chapter1.xhtml',
    structuralPath: const [0, 0, 0],
  );
  final firstWordId = StableId.content(
    sourceFingerprint: fingerprint,
    type: CanonicalNodeType.word,
    sourceDocumentPath: 'Text/chapter1.xhtml',
    structuralPath: const [0, 0, 0, 0],
  );
  final secondWordId = StableId.content(
    sourceFingerprint: fingerprint,
    type: CanonicalNodeType.word,
    sourceDocumentPath: 'Text/chapter1.xhtml',
    structuralPath: const [0, 0, 0, 1],
  );
  final locator = ReadingLocator(
    bookId: 'book_1',
    contentId: firstWordId,
    characterOffset: 2,
    wordOffset: 0,
  );
  final now = DateTime.utc(2026, 7, 14, 8);
  return Book(
    id: 'book_1',
    sourceFingerprint: fingerprint,
    sourcePath: sourcePath,
    metadata: const BookMetadata(
      title: 'A Sample Book',
      authors: ['Example Author'],
      language: 'en',
      languageConfidence: 0.98,
      languageSource: 'metadata',
    ),
    tableOfContents: [
      TocEntry(id: 'toc_1', title: 'Chapter One', chapterId: chapterId),
    ],
    chapters: [
      Chapter(
        id: chapterId,
        title: 'Chapter One',
        sourceHref: 'Text/chapter1.xhtml',
        order: 0,
        blocks: [
          ContentBlock(
            id: 'block_1',
            kind: BlockKind.paragraph,
            paragraph: Paragraph(
              id: paragraphId,
              text: 'Same text.',
              sentences: [
                Sentence(
                  id: sentenceId,
                  text: 'Same text.',
                  words: [
                    Word(id: firstWordId, text: 'Same', start: 0, end: 4),
                    Word(id: secondWordId, text: 'text', start: 5, end: 9),
                  ],
                ),
              ],
              formats: const [TextFormat(start: 0, end: 4, italic: true)],
            ),
          ),
        ],
      ),
    ],
    readingState: ReadingState(
      bookId: 'book_1',
      locator: locator,
      progress: 0.25,
      updatedAt: now,
      lastOpenedAt: now,
    ),
    annotations: [
      Annotation(
        id: 'annotation_1',
        bookId: 'book_1',
        kind: AnnotationKind.highlight,
        start: locator,
        end: locator,
        createdAt: now,
        updatedAt: now,
        color: 0xFFFFCC00,
      ),
    ],
    glossary: [
      GlossaryEntry(
        id: 'glossary_1',
        bookId: 'book_1',
        sourceTerm: 'flow',
        targetTerm: 'dòng chảy',
        targetLanguage: 'vi',
        revision: 1,
        updatedAt: now,
      ),
    ],
    chapterOverviews: [
      ChapterOverview(
        chapterId: chapterId,
        bigPicture: 'A test overview.',
        mainPoints: const ['One'],
        terminology: const ['Flow'],
        structure: 'Linear',
        pointsToWatch: const ['Details'],
        generatedAt: now,
        promptVersion: 1,
      ),
    ],
    importedAt: now,
  );
}
