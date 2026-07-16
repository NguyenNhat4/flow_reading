import 'package:flow_reading/domain/models/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every application failure has a readable message', () {
    const failures = <AppFailure>[
      InvalidEpubFailure(),
      UnsupportedDrmFailure(),
      FileSystemFailure(),
      DatabaseFailure(),
      CredentialStorageFailure(),
      NetworkFailure(),
      InvalidApiKeyFailure(),
      AiRateLimitFailure(),
      AiQuotaFailure(),
      AiRequestCancelledFailure(),
      AiProviderFailure(),
    ];

    for (final failure in failures) {
      expect(failure.message.trim(), isNotEmpty);
      expect(failure.toString(), failure.message);
    }
  });

  test('a failure can provide safe operation-specific wording', () {
    const failure = FileSystemFailure(
      message: 'The selected book could not be opened.',
    );

    expect(failure.message, 'The selected book could not be opened.');
  });
}
