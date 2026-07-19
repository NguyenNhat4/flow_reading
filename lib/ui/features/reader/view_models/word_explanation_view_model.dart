import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/models/word_explanation.dart';
import 'package:flow_reading/domain/use_cases/generate_word_explanation.dart';
import 'package:flow_reading/ui/core/ui_failure_mapper.dart';
import 'package:flow_reading/ui/features/reader/view_models/explanation_state.dart';
import 'package:flutter/foundation.dart';

typedef CreateWordExplanationViewModel =
    WordExplanationViewModel Function({
      required List<Chapter> chapters,
      required WordSelection selection,
      required ReadingLocator currentPosition,
    });

/// Presentation state for one contextual word explanation.
final class WordExplanationViewModel extends ChangeNotifier {
  WordExplanationViewModel({
    required GenerateWordExplanationUseCase generate,
    required List<Chapter> chapters,
    required WordSelection selection,
    required ReadingLocator currentPosition,
    UiFailureMapper failureMapper = const UiFailureMapper(),
  }) : this._(generate, chapters, selection, currentPosition, failureMapper);

  WordExplanationViewModel._(
    this._generate,
    this.chapters,
    this.selection,
    this.currentPosition,
    this._failureMapper,
  );

  final GenerateWordExplanationUseCase _generate;
  final List<Chapter> chapters;
  final WordSelection selection;
  final ReadingLocator currentPosition;
  final UiFailureMapper _failureMapper;

  ExplanationState<WordExplanation> _state = const ExplanationState();
  bool _disposed = false;

  ExplanationState<WordExplanation> get state => _state;

  Future<void> load() async {
    _state = const ExplanationState(status: ExplanationStatus.loading);
    _notify();
    try {
      final result = await _generate(
        chapters: chapters,
        selection: selection,
        currentPosition: currentPosition,
      );
      _state = ExplanationState(
        status: ExplanationStatus.success,
        explanation: result.explanation,
        fromCache: result.fromCache,
      );
    } catch (error) {
      _state = ExplanationState(
        status: ExplanationStatus.failure,
        errorMessage: _failureMapper.message(
          error,
          fallback: 'The word could not be explained.',
        ),
      );
    } finally {
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
