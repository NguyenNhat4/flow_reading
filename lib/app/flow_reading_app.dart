import 'package:flutter/material.dart';

class FlowReadingApp extends StatelessWidget {
  const FlowReadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flow Reading',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const Scaffold(
        body: SafeArea(child: Center(child: Text('Flow Reading'))),
      ),
    );
  }
}
