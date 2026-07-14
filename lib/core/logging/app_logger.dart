import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

abstract final class AppLogger {
  static final Logger _logger = Logger('flow_reading');
  static const _sensitiveKeys = <String>{
    'apiKey',
    'authorization',
    'bookContent',
    'epubBytes',
    'note',
    'selectedText',
  };

  static void configure(Level level) {
    hierarchicalLoggingEnabled = true;
    Logger.root.level = level;
    Logger.root.onRecord.listen((record) {
      final event = <String, Object?>{
        'timestamp': record.time.toUtc().toIso8601String(),
        'level': record.level.name,
        'logger': record.loggerName,
        'message': record.message,
        if (record.error != null)
          'errorType': record.error.runtimeType.toString(),
      };
      // ignore: avoid_print
      print(jsonEncode(event));
    });
  }

  static void info(String event, [Map<String, Object?> fields = const {}]) =>
      _logger.info(jsonEncode({'event': event, ..._redact(fields)}));

  static void error(String event, Object error, [StackTrace? stack]) =>
      _logger.severe(event, error, stack);

  static Map<String, Object?> _redact(Map<String, Object?> fields) => {
    for (final entry in fields.entries)
      entry.key: _sensitiveKeys.contains(entry.key)
          ? '[REDACTED]'
          : entry.value,
  };
}

final class SafeProviderObserver extends ProviderObserver {
  const SafeProviderObserver();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLogger.error('state.provider_failed', error, stackTrace);
  }
}
