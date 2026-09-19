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

  testWidgets('centralizar aproxima quando o circuito é pequeno',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LogiSnapApp());
    await tester.pump();

    final canvas = tester.getRect(find.byType(CircuitCanvas));
    final zoomInicial = _painter(tester).zoom;

    // Um componente só: sobra tela de monte, então o enquadramento tem de
    // aproximar em vez de deixar tudo minúsculo no meio.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Entrada'));
    await tester.pump();
    await tester.tapAt(canvas.center);
    await tester.pump();

    await tester.tap(find.byTooltip('Centralizar'));
    await tester.pump();

    expect(_painter(tester).zoom, greaterThan(zoomInicial));
    _esperaTudoNaTela(tester, canvas);
  });

  testWidgets('centralizar afasta quando o circuito não cabe',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LogiSnapApp());
    await tester.pump();

    final canvas = tester.getRect(find.byType(CircuitCanvas));
    final zoomInicial = _painter(tester).zoom;

    // Dois componentes quase nas pontas do canvas: no zoom atual eles não
    // cabem com folga, então centralizar precisa afastar. O segundo toque
    // desvia do botão de centralizar, que fica no canto inferior direito.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Entrada'));
    await tester.pump();
    await tester.tapAt(canvas.topLeft + const Offset(15, 15));
    await tester.pump();
    await tester.tapAt(canvas.bottomRight - const Offset(100, 15));
    await tester.pump();

    await tester.tap(find.byTooltip('Centralizar'));
    await tester.pump();

    expect(_painter(tester).zoom, lessThan(zoomInicial));
    _esperaTudoNaTela(tester, canvas);
  });
}

/// Depois de centralizar, todo o circuito tem de estar dentro do canvas.
void _esperaTudoNaTela(WidgetTester tester, Rect canvas) {
  final p = _painter(tester);
  for (final c in p.circuit.components) {
    final b = p.circuit.boundsOf(c);
    for (final canto in [Offset(b[0].toDouble(), b[1].toDouble()), Offset(b[2].toDouble(), b[3].toDouble())]) {
      final naTela = canto * p.zoom + p.pan;
      expect(naTela.dx, inInclusiveRange(0, canvas.width),
          reason: 'componente saiu da tela na horizontal');
      expect(naTela.dy, inInclusiveRange(0, canvas.height),
          reason: 'componente saiu da tela na vertical');
    }
  }
}
