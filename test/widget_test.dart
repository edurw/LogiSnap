// Teste de fumaça: garante que o app monta sem exceções.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logisim_mobile/main.dart';

void main() {
  testWidgets('o app inicia e monta a tela do editor',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LogisimMobileApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
