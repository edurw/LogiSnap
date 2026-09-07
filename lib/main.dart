import 'package:flutter/material.dart';

import 'ui/editor_screen.dart';

void main() {
  runApp(const LogiSnapApp());
}

class LogiSnapApp extends StatelessWidget {
  const LogiSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LogiSnap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
        useMaterial3: true,
      ),
      home: const EditorScreen(),
    );
  }
}
