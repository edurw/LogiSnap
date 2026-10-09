// O aviso que a importação mostra quando o arquivo traz componentes que o
// app ainda não tem.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logisnap/core/circ_format.dart';
import 'package:logisnap/core/circuit.dart';
import 'package:logisnap/ui/import_report_dialog.dart';

/// Abre o diálogo com [result] e espera a animação terminar.
Future<void> _abrir(WidgetTester tester, CircImportResult result) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showImportReport(context, result),
          child: const Text('importar'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('importar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista o que ficou de fora, com a quantidade e o botão Entendi',
      (WidgetTester tester) async {
    await _abrir(
      tester,
      CircImportResult(Circuit(), const [], omitted: const {
        'Flip-flop D': 2,
        'Memória RAM': 1,
      }),
    );

    expect(find.text('Alguns componentes não foram importados'), findsOneWidget);
    expect(find.text('•  Flip-flop D (2)'), findsOneWidget);
    expect(find.text('•  Memória RAM (1)'), findsOneWidget);
    // A explicação precisa dizer o que aconteceu com os fios.
    expect(find.textContaining('pontas em aberto'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Alguns componentes não foram importados'), findsNothing);
  });

  testWidgets('importação limpa não interrompe com diálogo nenhum',
      (WidgetTester tester) async {
    await _abrir(tester, CircImportResult(Circuit(), const []));

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('sem omissões, os outros avisos aparecem com o título antigo',
      (WidgetTester tester) async {
    await _abrir(
      tester,
      CircImportResult(Circuit(), const ['"Pin" em (10,10) usa 8 bits.']),
    );

    expect(find.text('Avisos da importação'), findsOneWidget);
    expect(find.textContaining('8 bits'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Entendi'), findsOneWidget);
  });
}
