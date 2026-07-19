import 'package:flow_reading/app/app_composition.dart';
import 'package:flow_reading/app/flow_reading_app.dart';
import 'package:flutter/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FlowReadingApp(composition: AppComposition.create()));
}
