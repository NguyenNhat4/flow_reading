import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flow_reading/domain/models/book_models.dart';
import 'package:flow_reading/domain/models/text_anchors.dart';
import 'package:flow_reading/domain/models/word_explanation.dart';
import 'package:flow_reading/domain/use_cases/generate_word_explanation.dart';
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
  }) : this._(generate, chapters, selection, currentPosition);

  WordExplanationViewModel._(
    this._generate,
    this.chapters,
    this.selection,
    this.currentPosition,
  );

  final GenerateWordExplanationUseCase _generate;
  final List<Chapter> chapters;
  final WordSelection selection;
  final ReadingLocator currentPosition;

  bool _isLoading = false;
  WordExplanation? _explanation;
  bool _fromCache = false;
  String? _errorMessage;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  WordExplanation? get explanation => _explanation;
  bool get fromCache => _fromCache;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      final result = await _generate(
        chapters: chapters,
        selection: selection,
        currentPosition: currentPosition,
      );
      _explanation = result.explanation;
      _fromCache = result.fromCache;
    } catch (error) {
      _errorMessage = switch (error) {
        AppFailure(:final message) => message,
        FormatException() => 'The AI response could not be understood.',
        _ => 'The word could not be explained.',
      };
    } finally {
      _isLoading = false;
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
