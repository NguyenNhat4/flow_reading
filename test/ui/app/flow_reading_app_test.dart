import 'dart:async';

import 'package:flow_reading/ui/app/app_dependencies.dart';
import 'package:flow_reading/ui/app/flow_reading_app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders in portrait and landscape', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in [const Size(400, 800), const Size(800, 400)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        FlowReadingApp(dependencies: Completer<AppDependencies>().future),
      );

      expect(find.text('Flow Reading'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
