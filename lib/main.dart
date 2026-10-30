import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const Scaffold(body: Center(child: Text('Hello, World!'))),
    );
  }
}
// cd /Users/askabdulhaseeb/Flutter/Local/ramzan && claude --resume bc262675-2be3-43a0-9afa-fa156fc776bd
