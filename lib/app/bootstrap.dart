import 'dart:ui';

import 'package:flow_reading/app/flow_reading_app.dart';
import 'package:flow_reading/core/config/app_environment.dart';
import 'package:flow_reading/core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> bootstrap({AppEnvironment? environment}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final resolvedEnvironment = environment ?? AppEnvironment.fromDefines();
  AppLogger.configure(resolvedEnvironment.logLevel);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error('flutter.framework', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('flutter.platform', error, stack);
    return true;
  };
  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(resolvedEnvironment),
      ],
      observers: const [SafeProviderObserver()],
      child: const FlowReadingApp(),
    ),
  );
}
