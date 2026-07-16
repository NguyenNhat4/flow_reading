import 'dart:async';

import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/passage_explanation.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/use_cases/generate_passage_explanation.dart';
import 'package:flutter/foundation.dart';

typedef CreatePassageExplanationViewModel =
    PassageExplanationViewModel Function({
      required List<Chapter> chapters,
      required PassageSelection selection,
      required ReadingLocator currentPosition,
    });

/// Presentation state for one cancellable passage explanation.
final class PassageExplanationViewModel extends ChangeNotifier {
  PassageExplanationViewModel({
    required GeneratePassageExplanationUseCase generate,
    required List<Chapter> chapters,
    required PassageSelection selection,
    required ReadingLocator currentPosition,
  }) : this._(generate, chapters, selection, currentPosition);

  PassageExplanationViewModel._(
    this._generate,
    this.chapters,
    this.selection,
    this.currentPosition,
  );

  final GeneratePassageExplanationUseCase _generate;
  final List<Chapter> chapters;
  final PassageSelection selection;
  final ReadingLocator currentPosition;

  PassageExplanationSession? _session;
  StreamSubscription<PassageExplanationEvent>? _subscription;
  bool _isLoading = false;
  PassageExplanation? _explanation;
  bool _fromCache = false;
  String? _errorMessage;
  int _generation = 0;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  PassageExplanation? get explanation => _explanation;
  bool get fromCache => _fromCache;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    await _session?.cancel();
    _isLoading = true;
    _explanation = null;
    _errorMessage = null;
    _notify();
    try {
      final session = await _generate.start(
        chapters: chapters,
        selection: selection,
        currentPosition: currentPosition,
      );
      if (_disposed || generation != _generation) {
        await session.cancel();
        return;
      }
      _session = session;
      _subscription = session.events.listen(
        (event) => _handleEvent(event, generation),
        onError: (Object error) => _fail(error, generation),
      );
    } catch (error) {
      _fail(error, generation);
    }
  }

  Future<void> cancel() async {
    if (!_isLoading) return;
    await _session?.cancel();
  }

  void _handleEvent(PassageExplanationEvent event, int generation) {
    if (_disposed || generation != _generation) return;
    switch (event) {
      case PassageExplanationCompleted(:final explanation, :final fromCache):
        _session = null;
        _subscription = null;
        _explanation = explanation;
        _fromCache = fromCache;
        _isLoading = false;
      case PassageExplanationFailed(:final error):
        _session = null;
        _subscription = null;
        _setFailure(error);
      case PassageExplanationCancelled():
        _session = null;
        _subscription = null;
        _isLoading = false;
        _errorMessage = 'The explanation was cancelled.';
    }
    _notify();
  }

  void _fail(Object error, int generation) {
    if (_disposed || generation != _generation) return;
    _setFailure(error);
    _notify();
  }

  void _setFailure(Object error) {
    _isLoading = false;
    _errorMessage = switch (error) {
      AppFailure(:final message) => message,
      FormatException() => 'The AI response could not be understood.',
      _ => 'The passage could not be explained.',
    };
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    unawaited(_session?.cancel());
    super.dispose();
  }
}
