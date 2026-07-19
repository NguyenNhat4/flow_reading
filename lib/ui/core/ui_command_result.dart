/// The outcome of a presentation command that may safely be shown by a view.
sealed class UiCommandResult<T> {
  const UiCommandResult();

  /// Whether the command completed successfully.
  bool get isSuccess => this is UiCommandSuccess<T>;
}

/// A successfully completed presentation command.
final class UiCommandSuccess<T> extends UiCommandResult<T> {
  const UiCommandSuccess(this.value);

  final T value;
}

/// A presentation command intentionally cancelled by the user.
final class UiCommandCancelled<T> extends UiCommandResult<T> {
  const UiCommandCancelled();
}

/// A failed presentation command with a user-safe message.
final class UiCommandFailure<T> extends UiCommandResult<T> {
  const UiCommandFailure(this.message);

  final String message;
}
