// Botão de centralizar: devolve o circuito para o meio da tela.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logisnap/main.dart';
import 'package:logisnap/ui/circuit_canvas.dart';
import 'package:logisnap/ui/circuit_painter.dart';

CircuitPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is CircuitPainter),
  );
  return paint.painter as CircuitPainter;
}

void main() {
  testWidgets('centralizar devolve o enquadramento depois de arrastar a tela',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LogiSnapApp());
    await tester.pump();

    final start = _painter(tester).pan;

    await tester.drag(find.byType(CircuitCanvas), const Offset(-120, -80));
    await tester.pump();
    expect(_painter(tester).pan, isNot(start));

    await tester.tap(find.byTooltip('Centralizar'));
    await tester.pump();
    expect(_painter(tester).pan, start);
  });
}
