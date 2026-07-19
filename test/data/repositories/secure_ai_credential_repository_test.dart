import 'package:flow_reading/data/repositories/secure_ai_credential_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('stores provider keys outside normal application persistence', () async {
    final repository = SecureAiCredentialRepository();

    expect(await repository.contains('openai'), isFalse);
    expect(await repository.read('openai'), isNull);

    await repository.write(providerId: 'OpenAI', apiKey: 'user-owned-key');

    expect(await repository.contains('openai'), isTrue);
    expect(await repository.read('openai'), 'user-owned-key');

    await repository.delete('openai');

    expect(await repository.contains('openai'), isFalse);
    expect(await repository.read('openai'), isNull);
  });

  test('isolates keys by normalized provider identifier', () async {
    final repository = SecureAiCredentialRepository();

    await repository.write(providerId: 'openai', apiKey: 'first-key');
    await repository.write(providerId: 'local_provider', apiKey: 'second-key');

    expect(await repository.read('OPENAI'), 'first-key');
    expect(await repository.read('local_provider'), 'second-key');
  });

  test('rejects empty keys and unsafe provider identifiers', () async {
    final repository = SecureAiCredentialRepository();

    expect(
      () => repository.write(providerId: 'openai', apiKey: '  '),
      throwsArgumentError,
    );
    expect(() => repository.read('../openai'), throwsArgumentError);
  });

  test('uses Android KeyStore-backed authenticated encryption defaults', () {
    final options = SecureAiCredentialRepository.androidOptions.toMap();

    expect(
      options['keyCipherAlgorithm'],
      'RSA_ECB_OAEPwithSHA_256andMGF1Padding',
    );
    expect(options['storageCipherAlgorithm'], 'AES_GCM_NoPadding');
    expect(options['storageNamespace'], 'flow_reading_ai_credentials');
    expect(options['encryptedSharedPreferences'], 'false');
  });
}
