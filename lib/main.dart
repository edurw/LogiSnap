import 'package:flutter/material.dart';

import 'ui/editor_screen.dart';

void main() {
  runApp(const LogisimMobileApp());
}

class LogisimMobileApp extends StatelessWidget {
  const LogisimMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logisim Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
        useMaterial3: true,
      ),
      home: const EditorScreen(),
    );
  }
}
