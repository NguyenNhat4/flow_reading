import 'dart:async';

import 'package:flow_reading/ui/core/reader_theme.dart';
import 'package:flow_reading/ui/features/reader/view_models/reader_view_model.dart';
import 'package:flow_reading/ui/features/reader/views/reader_layout_controls.dart';
import 'package:flow_reading/ui/features/reader/views/reader_action_menu.dart';
import 'package:flow_reading/ui/features/reader/views/swipeable_reader.dart';
import 'package:flow_reading/ui/features/reader/views/table_of_contents.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Displays a reader session whose state is owned by [ReaderViewModel].
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({required this.viewModel, super.key});

  final ReaderViewModel viewModel;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  bool _allowPop = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.viewModel.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.viewModel.saveForLifecycleChange();
    }
  }

  Future<void> _closeReader(Object? result) async {
    if (_closing) return;
    _closing = true;
    try {
      await widget.viewModel.savePosition();
    } catch (_) {
      // A local persistence failure must not trap the user in the reader.
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop(result);
  }

  Future<void> _changeLayout() async {
    final updated = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReaderLayoutControls(settings: widget.viewModel.settings),
    );
    if (updated == null || !mounted) return;
    final saved = await widget.viewModel.updateSettings(updated);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reader settings could not be saved.')),
      );
    }
  }

  Future<void> _showTableOfContents() async {
    final reference = await showReaderTableOfContents(
      context,
      widget.viewModel.tableOfContents,
    );
    if (reference == null || !mounted) return;
    if (!widget.viewModel.navigateTo(reference)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This section could not be opened.')),
      );
    }
  }

  Future<void> _handleAction(ReaderActionRequest request) async {
    if (request.action == ReaderAction.highlight) {
      final saved = await widget.viewModel.toggleHighlight(request.anchor);
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The highlight could not be saved.')),
        );
      }
      return;
    }
    if (request.action == ReaderAction.copy || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${request.action.label} requires internet access.'),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_closing) widget.viewModel.saveForLifecycleChange();
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final theme = readerThemeData(viewModel.settings.theme);
        final systemUiStyle = readerSystemUiStyle(theme.colorScheme);
        return Theme(
          key: const ValueKey('reader-theme'),
          data: theme,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            key: const ValueKey('reader-system-ui-style'),
            value: systemUiStyle,
            child: PopScope<Object?>(
              canPop: _allowPop,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) unawaited(_closeReader(result));
              },
              child: Scaffold(
                appBar: AppBar(
                  title: Text(viewModel.book.title),
                  systemOverlayStyle: systemUiStyle,
                  actions: [
                    IconButton(
                      tooltip: 'Table of contents',
                      onPressed: viewModel.tableOfContents.isEmpty
                          ? null
                          : _showTableOfContents,
                      icon: const Icon(Icons.list_alt),
                    ),
                    IconButton(
                      tooltip: 'Reader layout',
                      onPressed: viewModel.isLoaded ? _changeLayout : null,
                      icon: const Icon(Icons.text_fields),
                    ),
                  ],
                ),
                body: _ReaderBody(
                  viewModel: viewModel,
                  onActionSelected: _handleAction,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({required this.viewModel, required this.onActionSelected});

  final ReaderViewModel viewModel;
  final ReaderActionHandler onActionSelected;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.loadError != null) {
      return const Center(child: Text('The book could not be opened.'));
    }
    if (viewModel.chapters.isEmpty) {
      return const Center(child: Text('This book has no readable content.'));
    }
    return SwipeableReader(
      key: ValueKey('reader-generation-${viewModel.readerGeneration}'),
      chapters: viewModel.chapters,
      settings: viewModel.settings,
      initialLocator: viewModel.locator,
      highlights: viewModel.highlights,
      onPositionChanged: viewModel.showPosition,
      onActionSelected: onActionSelected,
    );
  }
}
