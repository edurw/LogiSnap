// LED, Botão, Clock e Constante voltaram à paleta: além de aparecerem lá,
// precisam funcionar de ponta a ponta (colocar, simular, interagir).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logisnap/core/component.dart';
import 'package:logisnap/core/geometry.dart';
import 'package:logisnap/core/values.dart';
import 'package:logisnap/main.dart';
import 'package:logisnap/state/editor_state.dart';

/// Coloca [tipo] em [onde] pelo caminho da paleta.
Component _coloca(EditorState st, ComponentType tipo, GridPoint onde) {
  st.choosePaletteType(tipo);
  st.placeAt(onde);
  return st.circuit.components.last;
}

void main() {
  testWidgets('a paleta oferece LED, Botão, Clock e Constante',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LogiSnapApp());
    await tester.pump();

    for (final rotulo in ['LED', 'Botão', 'Clock', 'Constante']) {
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, rotulo),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.widgetWithText(ChoiceChip, rotulo), findsOneWidget,
          reason: '"$rotulo" sumiu da paleta');
    }
  });

  test('botão acende o LED enquanto está pressionado', () {
    final st = EditorState();
    addTearDown(st.dispose);

    final botao = _coloca(st, ComponentType.button, const GridPoint(0, 0));
    final led = _coloca(st, ComponentType.led, const GridPoint(100, 0));
    st.linkTap(botao.location);
    st.linkTap(led.location);
    expect(st.circuit.wires, hasLength(1));

    expect(st.simulator.displayValueOf(led), LogicValue.zero);
    st.pressDownAt(botao.location);
    expect(st.simulator.displayValueOf(led), LogicValue.one);
    st.pressUpAll();
    expect(st.simulator.displayValueOf(led), LogicValue.zero);
  });

  test('clock alterna a cada meio ciclo e a constante nasce em 1', () {
    final st = EditorState();
    addTearDown(st.dispose);

    final clock = _coloca(st, ComponentType.clock, const GridPoint(0, 0));
    final led = _coloca(st, ComponentType.led, const GridPoint(100, 0));
    st.linkTap(clock.location);
    st.linkTap(led.location);

    expect(st.simulator.hasClock, isTrue);
    final antes = st.simulator.displayValueOf(led);
    st.simulator.tickClocks();
    expect(st.simulator.displayValueOf(led), isNot(antes));

    final constante =
        _coloca(st, ComponentType.constant, const GridPoint(0, 200));
    expect(constante.state, LogicValue.one);
    st.pokeAt(constante.location);
    expect(constante.state, LogicValue.zero);
  });
}
