/// Lifecycle of one contextual explanation request.
enum ExplanationStatus { initial, loading, success, failure, cancelled }

/// Immutable presentation state shared by contextual explanation features.
final class ExplanationState<T> {
  const ExplanationState({
    this.status = ExplanationStatus.initial,
    this.explanation,
    this.fromCache = false,
    this.errorMessage,
  });

  final ExplanationStatus status;
  final T? explanation;
  final bool fromCache;
  final String? errorMessage;

  bool get isLoading => status == ExplanationStatus.loading;
}
