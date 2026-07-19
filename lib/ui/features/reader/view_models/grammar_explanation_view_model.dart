import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/grammar_explanation.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/use_cases/generate_grammar_explanation.dart';
import 'package:flow_reading/ui/core/ui_failure_mapper.dart';
import 'package:flow_reading/ui/features/reader/view_models/explanation_state.dart';
import 'package:flutter/foundation.dart';

typedef CreateGrammarExplanationViewModel =
    GrammarExplanationViewModel Function({
      required List<Chapter> chapters,
      required PassageSelection selection,
      required ReadingLocator currentPosition,
    });

/// Presentation state for passage-specific grammar help.
final class GrammarExplanationViewModel extends ChangeNotifier {
  GrammarExplanationViewModel({
    required GenerateGrammarExplanationUseCase generate,
    required List<Chapter> chapters,
    required PassageSelection selection,
    required ReadingLocator currentPosition,
    UiFailureMapper failureMapper = const UiFailureMapper(),
  }) : this._(generate, chapters, selection, currentPosition, failureMapper);

  GrammarExplanationViewModel._(
    this._generate,
    this.chapters,
    this.selection,
    this.currentPosition,
    this._failureMapper,
  );

  final GenerateGrammarExplanationUseCase _generate;
  final List<Chapter> chapters;
  final PassageSelection selection;
  final ReadingLocator currentPosition;
  final UiFailureMapper _failureMapper;

  ExplanationState<GrammarExplanation> _state = const ExplanationState();
  bool _disposed = false;

  ExplanationState<GrammarExplanation> get state => _state;

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
          fallback: 'The grammar could not be explained.',
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
