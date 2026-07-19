import 'dart:async';

import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/passage_explanation.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/use_cases/generate_passage_explanation.dart';
import 'package:flow_reading/ui/core/ui_failure_mapper.dart';
import 'package:flow_reading/ui/features/reader/view_models/explanation_state.dart';
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
    UiFailureMapper failureMapper = const UiFailureMapper(),
  }) : this._(generate, chapters, selection, currentPosition, failureMapper);

  PassageExplanationViewModel._(
    this._generate,
    this.chapters,
    this.selection,
    this.currentPosition,
    this._failureMapper,
  );

  final GeneratePassageExplanationUseCase _generate;
  final List<Chapter> chapters;
  final PassageSelection selection;
  final ReadingLocator currentPosition;
  final UiFailureMapper _failureMapper;

  PassageExplanationSession? _session;
  StreamSubscription<PassageExplanationEvent>? _subscription;
  ExplanationState<PassageExplanation> _state = const ExplanationState();
  int _generation = 0;
  bool _disposed = false;

  ExplanationState<PassageExplanation> get state => _state;

  Future<void> load() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    await _session?.cancel();
    _state = const ExplanationState(status: ExplanationStatus.loading);
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
    if (!_state.isLoading) return;
    await _session?.cancel();
  }

  void _handleEvent(PassageExplanationEvent event, int generation) {
    if (_disposed || generation != _generation) return;
    switch (event) {
      case PassageExplanationCompleted(:final explanation, :final fromCache):
        _session = null;
        _subscription = null;
        _state = ExplanationState(
          status: ExplanationStatus.success,
          explanation: explanation,
          fromCache: fromCache,
        );
      case PassageExplanationFailed(:final error):
        _session = null;
        _subscription = null;
        _setFailure(error);
      case PassageExplanationCancelled():
        _session = null;
        _subscription = null;
        _state = const ExplanationState(
          status: ExplanationStatus.cancelled,
          errorMessage: 'The explanation was cancelled.',
        );
    }
    _notify();
  }

  void _fail(Object error, int generation) {
    if (_disposed || generation != _generation) return;
    _setFailure(error);
    _notify();
  }

  void _setFailure(Object error) {
    _state = ExplanationState(
      status: ExplanationStatus.failure,
      errorMessage: _failureMapper.message(
        error,
        fallback: 'The passage could not be explained.',
      ),
    );
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
