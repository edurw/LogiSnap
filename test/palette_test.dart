// LED, Botão, Clock e Constante voltaram à paleta: além de aparecerem lá,
// precisam funcionar de ponta a ponta (colocar, simular, interagir).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logisnap/core/component.dart';
import 'package:logisnap/core/geometry.dart';
import 'package:logisnap/core/values.dart';
import 'package:logisnap/main.dart';
import 'package:logisnap/state/editor_state.dart';
import 'package:logisnap/ui/component_icon.dart';
import 'package:logisnap/ui/component_palette.dart';

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

  test('todo componente pertence a exatamente uma categoria da paleta', () {
    final ocorrencias = <ComponentType, int>{};
    for (final categoria in kPaletteCategories) {
      for (final tipo in categoria.types) {
        ocorrencias[tipo] = (ocorrencias[tipo] ?? 0) + 1;
      }
    }
    // Nenhum tipo pode ficar de fora nem aparecer em duas categorias: é o
    // que garante que um componente novo não suma da paleta por esquecimento.
    for (final tipo in ComponentType.values) {
      expect(ocorrencias[tipo], 1,
          reason: '${tipo.displayName} deveria estar em uma categoria só');
    }
    expect(paletteTypes, hasLength(ComponentType.values.length));
  });

  testWidgets('categorias vazias não aparecem', (WidgetTester tester) async {
    await tester.pumpWidget(const LogiSnapApp());
    await tester.pump();

    expect(find.widgetWithText(FilterChip, 'E/S'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Portas'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Sequencial'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Fiação'), findsNothing);
  });

  testWidgets('trocar de categoria troca a fileira e mantém o componente armado',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LogiSnapApp());
    await tester.pump();

    // Começa em E/S.
    expect(find.widgetWithText(ChoiceChip, 'Entrada'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'AND'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Entrada'));
    await tester.pumpAndSettle();
    expect(find.text('Toque no canvas para adicionar: Entrada'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Portas'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'AND'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Entrada'), findsNothing);
    // Trocar de categoria não desarma o que estava escolhido.
    expect(find.text('Toque no canvas para adicionar: Entrada'), findsOneWidget);
  });

  testWidgets('todo tipo tem ícone desenhável', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Wrap(
          children: [for (final t in ComponentType.values) ComponentIcon(t)],
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ComponentIcon), findsNWidgets(ComponentType.values.length));
  });

  testWidgets('a paleta cabe na faixa pedida e mantém alvos de 48 dp',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LogiSnapApp());
    await tester.pump();

    // As duas fileiras juntas não podem roubar mais canvas do que o previsto.
    expect(tester.getSize(find.byType(ComponentPalette)).height,
        inInclusiveRange(96, 104));

    // Chip de categoria: 32 dp de desenho...
    final visual = tester.getSize(find.descendant(
      of: find.byType(FilterChip).first,
      matching: find.byType(Material),
    ).first);
    expect(visual.height, 32);

    // ...e 48 dp de alvo de toque, aqui e nos componentes.
    expect(tester.getSize(find.byType(FilterChip).first).height, 48);
    expect(tester.getSize(find.byType(ChoiceChip).first).height, 48);
  });
}
