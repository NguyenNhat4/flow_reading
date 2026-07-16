import 'package:flow_reading/domain/models/reader_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

ThemeData readerThemeData(ReaderTheme readerTheme) {
  final colorScheme = switch (readerTheme) {
    ReaderTheme.light => ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.light,
    ),
    ReaderTheme.dark => ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    ),
    ReaderTheme.paper =>
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF795548),
        brightness: Brightness.light,
      ).copyWith(
        surface: const Color(0xFFF4ECD8),
        onSurface: const Color(0xFF2F261D),
        surfaceContainerHighest: const Color(0xFFE6D8BB),
      ),
  };
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
  );
}

SystemUiOverlayStyle readerSystemUiStyle(ColorScheme colorScheme) {
  final iconBrightness = colorScheme.brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: colorScheme.surface,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: colorScheme.brightness,
    systemNavigationBarColor: colorScheme.surface,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}
