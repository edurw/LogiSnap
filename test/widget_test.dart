// Teste de fumaça: o app abre na splash e entra no editor sozinho.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logisnap/main.dart';
import 'package:logisnap/ui/editor_screen.dart';
import 'package:logisnap/ui/logo_mark.dart';
import 'package:logisnap/ui/splash_screen.dart';

void main() {
  testWidgets('o app abre na splash e depois mostra o editor',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LogiSnapApp());
    await tester.pump();

    // Primeira tela: marca e nome.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LogoMark), findsOneWidget);
    expect(find.text('LogiSnap'), findsOneWidget);
    expect(find.byType(EditorScreen), findsNothing);

    await tester.pump(SplashScreen.duracao + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // Passado o tempo, o editor entra no lugar — e a splash não volta.
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
