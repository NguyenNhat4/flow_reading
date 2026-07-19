import 'package:flow_reading/domain/models/app_failure.dart';

/// Maps application failures to messages that are safe to render.
final class UiFailureMapper {
  const UiFailureMapper();

  String message(Object error, {required String fallback}) => switch (error) {
    AppFailure(:final message) => message,
    FormatException() => 'The received data could not be understood.',
    _ => fallback,
  };
}
