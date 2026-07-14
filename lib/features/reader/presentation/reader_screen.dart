import 'dart:async';
import 'dart:io';

import 'package:flow_reading/features/reader/data/epub_asset_reader.dart';
import 'package:flow_reading/features/reader/domain/pagination.dart';
import 'package:flow_reading/shared/data/providers.dart';
import 'package:flow_reading/shared/domain/book.dart';
import 'package:flow_reading/shared/domain/repositories.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderData {
  const _ReaderData({
    required this.book,
    required this.stateRepository,
    required this.annotationRepository,
    required this.annotations,
  });

  final Book? book;
  final ReadingStateRepository stateRepository;
  final AnnotationRepository annotationRepository;
  final List<Annotation> annotations;
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  late final Future<_ReaderData> _data = _load();
  final _paginationEngine = const PaginationEngine();
  ReaderSettings _settings = const ReaderSettings();
  PaginationResult? _pagination;
  Size? _paginationSize;
  Book? _book;
  ReadingStateRepository? _stateRepository;
  AnnotationRepository? _annotationRepository;
  List<Annotation> _annotations = [];
  PageController? _pageController;
  int _pageIndex = 0;
  ReadingLocator? _logicalPosition;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<_ReaderData> _load() async {
    final bookRepository = await ref.read(bookRepositoryProvider.future);
    final stateRepository = await ref.read(
      readingStateRepositoryProvider.future,
    );
    final annotationRepository = await ref.read(
      annotationRepositoryProvider.future,
    );
    final book = await bookRepository.getById(widget.bookId);
    final annotations = await annotationRepository
        .watchForBook(widget.bookId)
        .first;
    return _ReaderData(
      book: book,
      stateRepository: stateRepository,
      annotationRepository: annotationRepository,
      annotations: annotations,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_savePosition());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    unawaited(_savePosition());
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReaderData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _statusScaffold(
            'Reader error',
            Icons.error_outline,
            'This book could not be opened. Your saved position is unchanged.',
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!;
        _book ??= data.book;
        _stateRepository ??= data.stateRepository;
        _annotationRepository ??= data.annotationRepository;
        if (_annotations.isEmpty) _annotations = data.annotations;
        final book = _book;
        if (book == null) {
          return _statusScaffold(
            'Book not found',
            Icons.menu_book_outlined,
            'This book is not in the local library.',
          );
        }
        if (!File(book.sourcePath).existsSync()) {
          return _statusScaffold(
            book.metadata.title,
            Icons.insert_drive_file_outlined,
            'The original EPUB file is missing. Return to the library and import it again.',
          );
        }
        return _buildReader(book);
      },
    );
  }

  Widget _buildReader(Book book) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          book.metadata.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Table of contents',
            onPressed: () => _showTableOfContents(book),
            icon: const Icon(Icons.format_list_numbered),
          ),
          IconButton(
            tooltip: 'Reader settings',
            onPressed: _showSettings,
            icon: const Icon(Icons.text_fields),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight - 42);
          _ensurePagination(book, size);
          final pagination = _pagination!;
          final palette = _palette(_settings.theme);
          return ColoredBox(
            color: palette.background,
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const PageScrollPhysics(),
                    itemCount: pagination.pages.length,
                    onPageChanged: (value) {
                      setState(() {
                        _pageIndex = value;
                        _logicalPosition = pagination.pages[value].locator(
                          book.id,
                        );
                      });
                      _scheduleSave();
                    },
                    itemBuilder: (context, index) => Semantics(
                      label: 'Page ${index + 1} of ${pagination.pages.length}',
                      child: _ReaderPageView(
                        page: pagination.pages[index],
                        book: book,
                        settings: _settings,
                        palette: palette,
                        annotations: _annotations,
                        onWord: _showWordActions,
                        onPassageAction: _passageAction,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: pagination.pages.length <= 1
                                ? 1
                                : _pageIndex / (pagination.pages.length - 1),
                            color: palette.accent,
                            backgroundColor: palette.foreground.withValues(
                              alpha: .12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_pageIndex + 1} / ${pagination.pages.length}',
                          style: TextStyle(color: palette.foreground),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _ensurePagination(Book book, Size size) {
    if (_pagination != null && _paginationSize == size) return;
    final preserved = _logicalPosition ?? book.readingState?.locator;
    final result = _paginationEngine.paginate(
      book: book,
      viewport: size,
      settings: _settings,
    );
    final index = preserved == null ? 0 : result.pageFor(preserved, book);
    final oldController = _pageController;
    _pagination = result;
    _paginationSize = size;
    _pageIndex = index.clamp(0, result.pages.length - 1);
    _logicalPosition = preserved ?? result.pages[_pageIndex].locator(book.id);
    _pageController = PageController(initialPage: _pageIndex);
    if (oldController != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => oldController.dispose(),
      );
    }
  }

  void _repaginate(ReaderSettings value) {
    setState(() {
      _settings = value;
      _pagination = null;
      _paginationSize = null;
    });
  }

  Future<void> _showSettings() async {
    var value = _settings;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void update(ReaderSettings next) {
            value = next;
            setSheetState(() {});
            _repaginate(next);
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reader settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ReaderTheme>(
                    segments: const [
                      ButtonSegment(
                        value: ReaderTheme.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ReaderTheme.dark,
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: ReaderTheme.paper,
                        label: Text('Paper'),
                      ),
                    ],
                    selected: {value.theme},
                    onSelectionChanged: (selection) =>
                        update(value.copyWith(theme: selection.first)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ReaderFont>(
                    initialValue: value.font,
                    decoration: const InputDecoration(labelText: 'Font family'),
                    items: const [
                      DropdownMenuItem(
                        value: ReaderFont.serif,
                        child: Text('Serif'),
                      ),
                      DropdownMenuItem(
                        value: ReaderFont.sans,
                        child: Text('Sans serif'),
                      ),
                      DropdownMenuItem(
                        value: ReaderFont.monospace,
                        child: Text('Monospace'),
                      ),
                    ],
                    onChanged: (font) {
                      if (font != null) update(value.copyWith(font: font));
                    },
                  ),
                  _SettingSlider(
                    label: 'Font size',
                    value: value.fontSize,
                    min: 13,
                    max: 32,
                    divisions: 19,
                    display: '${value.fontSize.round()} pt',
                    onChanged: (next) => update(value.copyWith(fontSize: next)),
                  ),
                  _SettingSlider(
                    label: 'Line spacing',
                    value: value.lineHeight,
                    min: 1.15,
                    max: 2,
                    divisions: 17,
                    display: value.lineHeight.toStringAsFixed(2),
                    onChanged: (next) =>
                        update(value.copyWith(lineHeight: next)),
                  ),
                  _SettingSlider(
                    label: 'Margins',
                    value: value.horizontalMargin,
                    min: 8,
                    max: 64,
                    divisions: 14,
                    display: '${value.horizontalMargin.round()} px',
                    onChanged: (next) =>
                        update(value.copyWith(horizontalMargin: next)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Layout automatically repaginates for portrait and landscape while keeping your logical position.',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showTableOfContents(Book book) async {
    final chapterId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .65,
          maxChildSize: .9,
          builder: (context, controller) => ListView(
            controller: controller,
            children: [
              const ListTile(title: Text('Table of contents')),
              ..._tocTiles(book.tableOfContents, 0),
            ],
          ),
        ),
      ),
    );
    if (chapterId == null || !mounted) return;
    final chapter = book.chapters
        .where((value) => value.id == chapterId)
        .firstOrNull;
    final contentId = chapter?.blocks
        .map((block) => block.paragraph?.id ?? block.image?.id)
        .whereType<String>()
        .firstOrNull;
    if (contentId == null) return;
    final page = _pagination!.pageFor(
      ReadingLocator(bookId: book.id, contentId: contentId),
      book,
    );
    await _pageController?.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  List<Widget> _tocTiles(List<TocEntry> entries, int depth) => [
    for (final entry in entries) ...[
      ListTile(
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 20, right: 16),
        title: Text(entry.title),
        onTap: () => Navigator.pop(context, entry.chapterId),
      ),
      ..._tocTiles(entry.children, depth + 1),
    ],
  ];

  void _showWordActions(Word word) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('“${word.text}”'),
              subtitle: const Text('Selected word'),
            ),
            Wrap(
              spacing: 4,
              alignment: WrapAlignment.center,
              children: [
                _ActionButton(
                  label: 'Define',
                  onPressed: () {
                    Navigator.pop(context);
                    _unavailableAction('Define');
                  },
                ),
                _ActionButton(
                  label: 'Ask AI',
                  onPressed: () {
                    Navigator.pop(context);
                    _unavailableAction('Ask AI');
                  },
                ),
                _ActionButton(
                  label: 'Translate',
                  onPressed: () {
                    Navigator.pop(context);
                    _unavailableAction('Translate');
                  },
                ),
                _ActionButton(
                  label: 'Highlight',
                  onPressed: () => _highlightWord(word),
                ),
                _ActionButton(
                  label: 'Copy',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: word.text));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _highlightWord(Word word) async {
    Navigator.pop(context);
    final now = DateTime.now().toUtc();
    final locator = ReadingLocator(bookId: widget.bookId, contentId: word.id);
    final annotation = Annotation(
      id: 'highlight_${now.microsecondsSinceEpoch}',
      bookId: widget.bookId,
      kind: AnnotationKind.highlight,
      start: locator,
      end: ReadingLocator(
        bookId: widget.bookId,
        contentId: word.id,
        characterOffset: word.text.length,
        affinity: LocatorAffinity.backward,
      ),
      createdAt: now,
      updatedAt: now,
      color: 0xFFFFD54F,
    );
    await _saveAnnotation(annotation);
  }

  Future<void> _passageAction(
    String action,
    PageSlice slice,
    int localStart,
    int localEnd,
    String selectedText,
  ) async {
    if (action == 'Highlight') {
      final now = DateTime.now().toUtc();
      await _saveAnnotation(
        Annotation(
          id: 'highlight_${now.microsecondsSinceEpoch}',
          bookId: widget.bookId,
          kind: AnnotationKind.highlight,
          start: ReadingLocator(
            bookId: widget.bookId,
            contentId: slice.contentId,
            characterOffset: slice.start + localStart,
          ),
          end: ReadingLocator(
            bookId: widget.bookId,
            contentId: slice.contentId,
            characterOffset: slice.start + localEnd,
            affinity: LocatorAffinity.backward,
          ),
          createdAt: now,
          updatedAt: now,
          color: 0xFFFFD54F,
        ),
      );
      return;
    }
    _unavailableAction(action);
  }

  Future<void> _saveAnnotation(Annotation annotation) async {
    await _annotationRepository?.save(annotation);
    if (!mounted) return;
    setState(() => _annotations = [..._annotations, annotation]);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Highlight saved to a stable text location.'),
      ),
    );
  }

  void _unavailableAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$action requires AI setup and connectivity. Local reading and your selection are unchanged.',
        ),
      ),
    );
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_savePosition()),
    );
  }

  Future<void> _savePosition() async {
    final repository = _stateRepository;
    final pagination = _pagination;
    if (repository == null || pagination == null || pagination.pages.isEmpty) {
      return;
    }
    final page = _pageIndex.clamp(0, pagination.pages.length - 1);
    final now = DateTime.now().toUtc();
    final locator =
        _logicalPosition ?? pagination.pages[page].locator(widget.bookId);
    await repository.save(
      ReadingState(
        bookId: widget.bookId,
        locator: locator,
        progress: pagination.pages.length <= 1
            ? 1
            : page / (pagination.pages.length - 1),
        updatedAt: now,
        lastOpenedAt: now,
      ),
    );
  }

  Scaffold _statusScaffold(String title, IconData icon, String message) =>
      Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}

class _ReaderPageView extends StatelessWidget {
  const _ReaderPageView({
    required this.page,
    required this.book,
    required this.settings,
    required this.palette,
    required this.annotations,
    required this.onWord,
    required this.onPassageAction,
  });

  final ReaderPage page;
  final Book book;
  final ReaderSettings settings;
  final _ReaderPalette palette;
  final List<Annotation> annotations;
  final ValueChanged<Word> onWord;
  final Future<void> Function(String, PageSlice, int, int, String)
  onPassageAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: settings.horizontalMargin,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final slice in page.slices)
                if (slice.block.image case final image?)
                  Expanded(
                    child: FutureBuilder(
                      future: EpubAssetReader.load(
                        book.sourcePath,
                        image.relativePath,
                      ),
                      builder: (context, snapshot) => snapshot.data == null
                          ? Semantics(
                              label: image.altText ?? 'Book image unavailable',
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                ),
                              ),
                            )
                          : Image.memory(
                              snapshot.data!,
                              fit: BoxFit.contain,
                              semanticLabel: image.altText ?? 'Book image',
                            ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SelectableSlice(
                      slice: slice,
                      settings: settings,
                      foreground: palette.foreground,
                      annotations: annotations,
                      onWord: onWord,
                      onPassageAction: onPassageAction,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableSlice extends StatefulWidget {
  const _SelectableSlice({
    required this.slice,
    required this.settings,
    required this.foreground,
    required this.annotations,
    required this.onWord,
    required this.onPassageAction,
  });

  final PageSlice slice;
  final ReaderSettings settings;
  final Color foreground;
  final List<Annotation> annotations;
  final ValueChanged<Word> onWord;
  final Future<void> Function(String, PageSlice, int, int, String)
  onPassageAction;

  @override
  State<_SelectableSlice> createState() => _SelectableSliceState();
}

class _SelectableSliceState extends State<_SelectableSlice> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    final paragraph = widget.slice.block.paragraph!;
    final baseStyle = PaginationEngine.textStyleFor(
      widget.slice.block.kind,
      widget.settings,
    ).copyWith(color: widget.foreground);
    final spans = _spans(paragraph, baseStyle);
    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: switch (paragraph.alignment) {
        TextAlignment.start => TextAlign.start,
        TextAlignment.center => TextAlign.center,
        TextAlignment.end => TextAlign.end,
        TextAlignment.justify => TextAlign.justify,
      },
      semanticsLabel: widget.slice.text,
      contextMenuBuilder: (context, editableTextState) {
        final selection = editableTextState.textEditingValue.selection;
        final value = editableTextState.textEditingValue.text;
        if (!selection.isValid || selection.isCollapsed) {
          return AdaptiveTextSelectionToolbar.editableText(
            editableTextState: editableTextState,
          );
        }
        void run(String action) {
          editableTextState.hideToolbar();
          widget.onPassageAction(
            action,
            widget.slice,
            selection.start,
            selection.end,
            selection.textInside(value),
          );
        }

        final items = <ContextMenuButtonItem>[
          ContextMenuButtonItem(
            label: 'Explain',
            onPressed: () => run('Explain'),
          ),
          ContextMenuButtonItem(
            label: 'Ask AI',
            onPressed: () => run('Ask AI'),
          ),
          ContextMenuButtonItem(
            label: 'Translate',
            onPressed: () => run('Translate'),
          ),
          ContextMenuButtonItem(
            label: 'Summarize',
            onPressed: () => run('Summarize'),
          ),
          ContextMenuButtonItem(
            label: 'Explain Grammar',
            onPressed: () => run('Explain Grammar'),
          ),
          ContextMenuButtonItem(
            label: 'Highlight',
            onPressed: () => run('Highlight'),
          ),
          ...editableTextState.contextMenuButtonItems.where(
            (item) => item.type == ContextMenuButtonType.copy,
          ),
        ];
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: items,
        );
      },
    );
  }

  List<InlineSpan> _spans(Paragraph paragraph, TextStyle baseStyle) {
    final sliceStart = widget.slice.start;
    final sliceEnd = widget.slice.end;
    final words = _wordRanges(paragraph);
    final highlights = <({int start, int end})>[];
    for (final annotation in widget.annotations.where(
      (a) => a.kind == AnnotationKind.highlight,
    )) {
      final book = Book(
        id: annotation.bookId,
        sourceFingerprint: '',
        sourcePath: '',
        metadata: const BookMetadata(title: '', authors: [], language: 'und'),
        tableOfContents: const [],
        chapters: [
          Chapter(
            id: '',
            title: '',
            sourceHref: '',
            order: 0,
            blocks: [widget.slice.block],
          ),
        ],
        importedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      final start = normalizeLocator(book, annotation.start);
      final end = normalizeLocator(book, annotation.end);
      if (start.contentId == paragraph.id && end.contentId == paragraph.id) {
        highlights.add((
          start: start.characterOffset,
          end: end.characterOffset,
        ));
      }
    }
    final boundaries = <int>{sliceStart, sliceEnd};
    for (final format in paragraph.formats) {
      if (format.end > sliceStart && format.start < sliceEnd) {
        boundaries.add(format.start.clamp(sliceStart, sliceEnd));
        boundaries.add(format.end.clamp(sliceStart, sliceEnd));
      }
    }
    for (final word in words) {
      if (word.end > sliceStart && word.start < sliceEnd) {
        boundaries.add(word.start.clamp(sliceStart, sliceEnd));
        boundaries.add(word.end.clamp(sliceStart, sliceEnd));
      }
    }
    for (final highlight in highlights) {
      boundaries.add(highlight.start.clamp(sliceStart, sliceEnd));
      boundaries.add(highlight.end.clamp(sliceStart, sliceEnd));
    }
    final sorted = boundaries.toList()..sort();
    final result = <InlineSpan>[];
    for (var index = 0; index < sorted.length - 1; index++) {
      final start = sorted[index];
      final end = sorted[index + 1];
      if (end <= start) continue;
      final format = paragraph.formats
          .where((value) => value.start < end && value.end > start)
          .firstOrNull;
      final word = words
          .where((value) => value.start <= start && value.end >= end)
          .firstOrNull;
      final highlighted = highlights.any(
        (value) => value.start < end && value.end > start,
      );
      TapGestureRecognizer? recognizer;
      if (word != null) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onWord(word.word);
        _recognizers.add(recognizer);
      }
      result.add(
        TextSpan(
          text: paragraph.text.substring(start, end),
          recognizer: recognizer,
          style: baseStyle.copyWith(
            fontWeight: format?.bold == true
                ? FontWeight.bold
                : baseStyle.fontWeight,
            fontStyle: format?.italic == true ? FontStyle.italic : null,
            decoration: format?.underline == true || format?.link != null
                ? TextDecoration.underline
                : null,
            color: format?.link != null ? Colors.blue : baseStyle.color,
            backgroundColor: highlighted ? const Color(0x88FFD54F) : null,
          ),
        ),
      );
    }
    return result;
  }

  List<_WordRange> _wordRanges(Paragraph paragraph) {
    final result = <_WordRange>[];
    var cursor = 0;
    for (final sentence in paragraph.sentences) {
      final found = paragraph.text.indexOf(sentence.text, cursor);
      final sentenceStart = found < 0 ? cursor : found;
      for (final word in sentence.words) {
        result.add(
          _WordRange(
            word,
            sentenceStart + word.start,
            sentenceStart + word.end,
          ),
        );
      }
      cursor = sentenceStart + sentence.text.length;
    }
    return result;
  }
}

class _WordRange {
  const _WordRange(this.word, this.start, this.end);
  final Word word;
  final int start;
  final int end;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: onPressed, child: Text(label));
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: display,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('$label: $display'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: display,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _ReaderPalette {
  const _ReaderPalette(this.background, this.foreground, this.accent);
  final Color background;
  final Color foreground;
  final Color accent;
}

_ReaderPalette _palette(ReaderTheme theme) => switch (theme) {
  ReaderTheme.light => const _ReaderPalette(
    Color(0xFFFFFFFF),
    Color(0xFF171717),
    Color(0xFF385D8A),
  ),
  ReaderTheme.dark => const _ReaderPalette(
    Color(0xFF17191C),
    Color(0xFFE6E2DA),
    Color(0xFF9FBCE0),
  ),
  ReaderTheme.paper => const _ReaderPalette(
    Color(0xFFF2E8CF),
    Color(0xFF332B22),
    Color(0xFF7B5A33),
  ),
};

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
