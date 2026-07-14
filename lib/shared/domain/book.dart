enum BlockKind { paragraph, heading, listItem, image, divider }

enum AnnotationKind { highlight, note, bookmark }

enum TextAlignment { start, center, end, justify }

enum LocatorAffinity { forward, backward }

typedef Json = Map<String, Object?>;

class TextFormat {
  const TextFormat({
    required this.start,
    required this.end,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.link,
  });

  factory TextFormat.fromJson(Json json) => TextFormat(
    start: json['start']! as int,
    end: json['end']! as int,
    bold: json['bold'] as bool? ?? false,
    italic: json['italic'] as bool? ?? false,
    underline: json['underline'] as bool? ?? false,
    link: json['link'] as String?,
  );

  final int start;
  final int end;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? link;

  Json toJson() => {
    'start': start,
    'end': end,
    'bold': bold,
    'italic': italic,
    'underline': underline,
    if (link != null) 'link': link,
  };
}

class Word {
  const Word({
    required this.id,
    required this.text,
    required this.start,
    required this.end,
  });

  factory Word.fromJson(Json json) => Word(
    id: json['id']! as String,
    text: json['text']! as String,
    start: json['start']! as int,
    end: json['end']! as int,
  );

  final String id;
  final String text;
  final int start;
  final int end;
  Json toJson() => {'id': id, 'text': text, 'start': start, 'end': end};
}

class Sentence {
  const Sentence({required this.id, required this.text, required this.words});

  factory Sentence.fromJson(Json json) => Sentence(
    id: json['id']! as String,
    text: json['text']! as String,
    words: _jsonList(json['words']).map(Word.fromJson).toList(),
  );

  final String id;
  final String text;
  final List<Word> words;
  Json toJson() => {
    'id': id,
    'text': text,
    'words': words.map((value) => value.toJson()).toList(),
  };
}

class Paragraph {
  const Paragraph({
    required this.id,
    required this.text,
    required this.sentences,
    this.formats = const [],
    this.alignment = TextAlignment.start,
  });

  factory Paragraph.fromJson(Json json) => Paragraph(
    id: json['id']! as String,
    text: json['text']! as String,
    sentences: _jsonList(json['sentences']).map(Sentence.fromJson).toList(),
    formats: _jsonList(json['formats']).map(TextFormat.fromJson).toList(),
    alignment: _enumByName(TextAlignment.values, json['alignment'] as String),
  );

  final String id;
  final String text;
  final List<Sentence> sentences;
  final List<TextFormat> formats;
  final TextAlignment alignment;
  Json toJson() => {
    'id': id,
    'text': text,
    'sentences': sentences.map((value) => value.toJson()).toList(),
    'formats': formats.map((value) => value.toJson()).toList(),
    'alignment': alignment.name,
  };
}

class BookImage {
  const BookImage({
    required this.id,
    required this.relativePath,
    required this.mediaType,
    this.altText,
    this.width,
    this.height,
  });

  factory BookImage.fromJson(Json json) => BookImage(
    id: json['id']! as String,
    relativePath: json['relativePath']! as String,
    mediaType: json['mediaType']! as String,
    altText: json['altText'] as String?,
    width: json['width'] as int?,
    height: json['height'] as int?,
  );

  final String id;
  final String relativePath;
  final String mediaType;
  final String? altText;
  final int? width;
  final int? height;
  Json toJson() => {
    'id': id,
    'relativePath': relativePath,
    'mediaType': mediaType,
    if (altText != null) 'altText': altText,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
  };
}

class ContentBlock {
  const ContentBlock({
    required this.id,
    required this.kind,
    this.paragraph,
    this.image,
  }) : assert(
         (paragraph == null) != (image == null) || kind == BlockKind.divider,
         'A content block must carry the matching payload.',
       );

  factory ContentBlock.fromJson(Json json) => ContentBlock(
    id: json['id']! as String,
    kind: _enumByName(BlockKind.values, json['kind']! as String),
    paragraph: json['paragraph'] == null
        ? null
        : Paragraph.fromJson(_json(json['paragraph'])),
    image: json['image'] == null
        ? null
        : BookImage.fromJson(_json(json['image'])),
  );

  final String id;
  final BlockKind kind;
  final Paragraph? paragraph;
  final BookImage? image;
  Json toJson() => {
    'id': id,
    'kind': kind.name,
    if (paragraph != null) 'paragraph': paragraph!.toJson(),
    if (image != null) 'image': image!.toJson(),
  };
}

class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.sourceHref,
    required this.order,
    required this.blocks,
  });

  factory Chapter.fromJson(Json json) => Chapter(
    id: json['id']! as String,
    title: json['title']! as String,
    sourceHref: json['sourceHref']! as String,
    order: json['order']! as int,
    blocks: _jsonList(json['blocks']).map(ContentBlock.fromJson).toList(),
  );

  final String id;
  final String title;
  final String sourceHref;
  final int order;
  final List<ContentBlock> blocks;
  Json toJson() => {
    'id': id,
    'title': title,
    'sourceHref': sourceHref,
    'order': order,
    'blocks': blocks.map((value) => value.toJson()).toList(),
  };
}

class TocEntry {
  const TocEntry({
    required this.id,
    required this.title,
    required this.chapterId,
    this.fragment,
    this.children = const [],
  });

  factory TocEntry.fromJson(Json json) => TocEntry(
    id: json['id']! as String,
    title: json['title']! as String,
    chapterId: json['chapterId']! as String,
    fragment: json['fragment'] as String?,
    children: _jsonList(json['children']).map(TocEntry.fromJson).toList(),
  );

  final String id;
  final String title;
  final String chapterId;
  final String? fragment;
  final List<TocEntry> children;
  Json toJson() => {
    'id': id,
    'title': title,
    'chapterId': chapterId,
    if (fragment != null) 'fragment': fragment,
    'children': children.map((value) => value.toJson()).toList(),
  };
}

class BookMetadata {
  const BookMetadata({
    required this.title,
    required this.authors,
    required this.language,
    this.languageConfidence,
    this.languageSource,
    this.publisher,
    this.description,
    this.coverImageId,
  });

  factory BookMetadata.fromJson(Json json) => BookMetadata(
    title: json['title']! as String,
    authors: (json['authors']! as List<Object?>).cast<String>(),
    language: json['language']! as String,
    languageConfidence: (json['languageConfidence'] as num?)?.toDouble(),
    languageSource: json['languageSource'] as String?,
    publisher: json['publisher'] as String?,
    description: json['description'] as String?,
    coverImageId: json['coverImageId'] as String?,
  );

  final String title;
  final List<String> authors;
  final String language;
  final double? languageConfidence;
  final String? languageSource;
  final String? publisher;
  final String? description;
  final String? coverImageId;
  Json toJson() => {
    'title': title,
    'authors': authors,
    'language': language,
    if (languageConfidence != null) 'languageConfidence': languageConfidence,
    if (languageSource != null) 'languageSource': languageSource,
    if (publisher != null) 'publisher': publisher,
    if (description != null) 'description': description,
    if (coverImageId != null) 'coverImageId': coverImageId,
  };
}

class ReadingLocator {
  const ReadingLocator({
    required this.bookId,
    required this.contentId,
    this.characterOffset = 0,
    this.wordOffset = 0,
    this.affinity = LocatorAffinity.forward,
    this.formatVersion = currentFormatVersion,
    this.migrationVersion = 0,
  });

  static const currentFormatVersion = 1;

  factory ReadingLocator.fromJson(Json json) => ReadingLocator(
    bookId: json['bookId']! as String,
    contentId: json['contentId']! as String,
    characterOffset: json['characterOffset'] as int? ?? 0,
    wordOffset: json['wordOffset'] as int? ?? 0,
    affinity: _enumByName(LocatorAffinity.values, json['affinity']! as String),
    formatVersion: json['formatVersion'] as int? ?? 1,
    migrationVersion: json['migrationVersion'] as int? ?? 0,
  );

  final String bookId;
  final String contentId;
  final int characterOffset;
  final int wordOffset;
  final LocatorAffinity affinity;
  final int formatVersion;
  final int migrationVersion;
  Json toJson() => {
    'bookId': bookId,
    'contentId': contentId,
    'characterOffset': characterOffset,
    'wordOffset': wordOffset,
    'affinity': affinity.name,
    'formatVersion': formatVersion,
    'migrationVersion': migrationVersion,
  };
}

class ReadingState {
  const ReadingState({
    required this.bookId,
    required this.locator,
    required this.progress,
    required this.updatedAt,
    this.lastOpenedAt,
  });

  factory ReadingState.fromJson(Json json) => ReadingState(
    bookId: json['bookId']! as String,
    locator: ReadingLocator.fromJson(_json(json['locator'])),
    progress: (json['progress']! as num).toDouble(),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    lastOpenedAt: json['lastOpenedAt'] == null
        ? null
        : DateTime.parse(json['lastOpenedAt']! as String),
  );

  final String bookId;
  final ReadingLocator locator;
  final double progress;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  Json toJson() => {
    'bookId': bookId,
    'locator': locator.toJson(),
    'progress': progress,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (lastOpenedAt != null)
      'lastOpenedAt': lastOpenedAt!.toUtc().toIso8601String(),
  };
}

class Annotation {
  const Annotation({
    required this.id,
    required this.bookId,
    required this.kind,
    required this.start,
    required this.end,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.color,
  });

  factory Annotation.fromJson(Json json) => Annotation(
    id: json['id']! as String,
    bookId: json['bookId']! as String,
    kind: _enumByName(AnnotationKind.values, json['kind']! as String),
    start: ReadingLocator.fromJson(_json(json['start'])),
    end: ReadingLocator.fromJson(_json(json['end'])),
    createdAt: DateTime.parse(json['createdAt']! as String),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    note: json['note'] as String?,
    color: json['color'] as int?,
  );

  final String id;
  final String bookId;
  final AnnotationKind kind;
  final ReadingLocator start;
  final ReadingLocator end;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? note;
  final int? color;
  Json toJson() => {
    'id': id,
    'bookId': bookId,
    'kind': kind.name,
    'start': start.toJson(),
    'end': end.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (note != null) 'note': note,
    if (color != null) 'color': color,
  };
}

class GlossaryEntry {
  const GlossaryEntry({
    required this.id,
    required this.bookId,
    required this.sourceTerm,
    required this.targetTerm,
    required this.targetLanguage,
    required this.revision,
    required this.updatedAt,
    this.context,
  });

  factory GlossaryEntry.fromJson(Json json) => GlossaryEntry(
    id: json['id']! as String,
    bookId: json['bookId']! as String,
    sourceTerm: json['sourceTerm']! as String,
    targetTerm: json['targetTerm']! as String,
    targetLanguage: json['targetLanguage']! as String,
    revision: json['revision']! as int,
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    context: json['context'] as String?,
  );

  final String id;
  final String bookId;
  final String sourceTerm;
  final String targetTerm;
  final String targetLanguage;
  final int revision;
  final DateTime updatedAt;
  final String? context;
  Json toJson() => {
    'id': id,
    'bookId': bookId,
    'sourceTerm': sourceTerm,
    'targetTerm': targetTerm,
    'targetLanguage': targetLanguage,
    'revision': revision,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (context != null) 'context': context,
  };
}

class ChapterOverview {
  const ChapterOverview({
    required this.chapterId,
    required this.bigPicture,
    required this.mainPoints,
    required this.terminology,
    required this.structure,
    required this.pointsToWatch,
    required this.generatedAt,
    required this.promptVersion,
  });

  factory ChapterOverview.fromJson(Json json) => ChapterOverview(
    chapterId: json['chapterId']! as String,
    bigPicture: json['bigPicture']! as String,
    mainPoints: (json['mainPoints']! as List<Object?>).cast<String>(),
    terminology: (json['terminology']! as List<Object?>).cast<String>(),
    structure: json['structure']! as String,
    pointsToWatch: (json['pointsToWatch']! as List<Object?>).cast<String>(),
    generatedAt: DateTime.parse(json['generatedAt']! as String),
    promptVersion: json['promptVersion']! as int,
  );

  final String chapterId;
  final String bigPicture;
  final List<String> mainPoints;
  final List<String> terminology;
  final String structure;
  final List<String> pointsToWatch;
  final DateTime generatedAt;
  final int promptVersion;
  Json toJson() => {
    'chapterId': chapterId,
    'bigPicture': bigPicture,
    'mainPoints': mainPoints,
    'terminology': terminology,
    'structure': structure,
    'pointsToWatch': pointsToWatch,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'promptVersion': promptVersion,
  };
}

class Book {
  const Book({
    required this.id,
    required this.sourceFingerprint,
    required this.sourcePath,
    required this.metadata,
    required this.tableOfContents,
    required this.chapters,
    this.images = const [],
    required this.importedAt,
    this.annotations = const [],
    this.glossary = const [],
    this.chapterOverviews = const [],
    this.readingState,
    this.modelVersion = currentModelVersion,
  });

  static const currentModelVersion = 1;

  factory Book.fromJson(Json json) => Book(
    id: json['id']! as String,
    sourceFingerprint: json['sourceFingerprint']! as String,
    sourcePath: json['sourcePath']! as String,
    metadata: BookMetadata.fromJson(_json(json['metadata'])),
    tableOfContents: _jsonList(
      json['tableOfContents'],
    ).map(TocEntry.fromJson).toList(),
    chapters: _jsonList(json['chapters']).map(Chapter.fromJson).toList(),
    images: _jsonList(json['images']).map(BookImage.fromJson).toList(),
    importedAt: DateTime.parse(json['importedAt']! as String),
    annotations: _jsonList(
      json['annotations'],
    ).map(Annotation.fromJson).toList(),
    glossary: _jsonList(json['glossary']).map(GlossaryEntry.fromJson).toList(),
    chapterOverviews: _jsonList(
      json['chapterOverviews'],
    ).map(ChapterOverview.fromJson).toList(),
    readingState: json['readingState'] == null
        ? null
        : ReadingState.fromJson(_json(json['readingState'])),
    modelVersion: json['modelVersion'] as int? ?? 1,
  );

  final String id;
  final String sourceFingerprint;
  final String sourcePath;
  final BookMetadata metadata;
  final List<TocEntry> tableOfContents;
  final List<Chapter> chapters;
  final List<BookImage> images;
  final List<Annotation> annotations;
  final List<GlossaryEntry> glossary;
  final List<ChapterOverview> chapterOverviews;
  final ReadingState? readingState;
  final DateTime importedAt;
  final int modelVersion;

  Book withSourcePath(String value) => Book(
    id: id,
    sourceFingerprint: sourceFingerprint,
    sourcePath: value,
    metadata: metadata,
    tableOfContents: tableOfContents,
    chapters: chapters,
    images: images,
    importedAt: importedAt,
    annotations: annotations,
    glossary: glossary,
    chapterOverviews: chapterOverviews,
    readingState: readingState,
    modelVersion: modelVersion,
  );

  Book withMetadata(BookMetadata value) => Book(
    id: id,
    sourceFingerprint: sourceFingerprint,
    sourcePath: sourcePath,
    metadata: value,
    tableOfContents: tableOfContents,
    chapters: chapters,
    images: images,
    importedAt: importedAt,
    annotations: annotations,
    glossary: glossary,
    chapterOverviews: chapterOverviews,
    readingState: readingState,
    modelVersion: modelVersion,
  );

  Json toJson() => {
    'id': id,
    'sourceFingerprint': sourceFingerprint,
    'sourcePath': sourcePath,
    'metadata': metadata.toJson(),
    'tableOfContents': tableOfContents.map((value) => value.toJson()).toList(),
    'chapters': chapters.map((value) => value.toJson()).toList(),
    'images': images.map((value) => value.toJson()).toList(),
    'annotations': annotations.map((value) => value.toJson()).toList(),
    'glossary': glossary.map((value) => value.toJson()).toList(),
    'chapterOverviews': chapterOverviews
        .map((value) => value.toJson())
        .toList(),
    if (readingState != null) 'readingState': readingState!.toJson(),
    'importedAt': importedAt.toUtc().toIso8601String(),
    'modelVersion': modelVersion,
  };
}

Json _json(Object? value) => (value! as Map<Object?, Object?>).map(
  (key, value) => MapEntry(key! as String, value),
);

List<Json> _jsonList(Object? value) =>
    (value as List<Object?>? ?? const []).map(_json).toList(growable: false);

T _enumByName<T extends Enum>(List<T> values, String name) =>
    values.firstWhere((value) => value.name == name);
