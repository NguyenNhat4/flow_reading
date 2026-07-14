import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

enum AppFlavor { development, staging, production }

class AppEnvironment {
  const AppEnvironment({required this.flavor, required this.logLevel});

  factory AppEnvironment.fromDefines() {
    const flavorValue = String.fromEnvironment(
      'APP_FLAVOR',
      defaultValue: 'development',
    );
    const logValue = String.fromEnvironment('LOG_LEVEL', defaultValue: 'INFO');
    return AppEnvironment(
      flavor: AppFlavor.values.firstWhere(
        (value) => value.name == flavorValue,
        orElse: () => AppFlavor.development,
      ),
      logLevel: Level.LEVELS.firstWhere(
        (level) => level.name == logValue.toUpperCase(),
        orElse: () => Level.INFO,
      ),
    );
  }

  final AppFlavor flavor;
  final Level logLevel;
}

final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => throw StateError('Override AppEnvironment during bootstrap.'),
);
