import 'package:flow_reading/app/flow_reading_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an accessible empty library in portrait and landscape', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const ProviderScope(child: FlowReadingApp()));
    expect(find.text('Your library is ready'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Empty library')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(900, 450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
    expect(find.text('Your library is ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
