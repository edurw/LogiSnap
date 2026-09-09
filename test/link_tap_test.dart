// Ligação por toques (modo Fio): toca na origem, toca no destino, fio pronto.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logisnap/core/component.dart';
import 'package:logisnap/core/geometry.dart';
import 'package:logisnap/core/values.dart';
import 'package:logisnap/main.dart';
import 'package:logisnap/state/editor_state.dart';
import 'package:logisnap/ui/circuit_canvas.dart';
import 'package:logisnap/ui/circuit_painter.dart';

CircuitPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is CircuitPainter),
  );
  return paint.painter as CircuitPainter;
}

/// Pino de entrada em (0,0) e um AND virado para leste ancorado em (100,0):
/// saída do pino em (0,0), entradas do AND em (50,-10) e (50,10).
EditorState _cenario() {
  final st = EditorState();
  st.circuit.addComponent(Component(
    id: st.circuit.newId(),
    type: ComponentType.inputPin,
    x: 0,
    y: 0,
  ));
  st.circuit.addComponent(Component(
    id: st.circuit.newId(),
    type: ComponentType.andGate,
    x: 100,
    y: 0,
    inputs: 2,
  ));
  return st;
}

void main() {
  test('dois toques em terminais criam o fio roteado', () {
    final st = _cenario();
    addTearDown(st.dispose);

    st.linkTap(const GridPoint(0, 0));
    expect(st.linkAnchor?.at, const GridPoint(0, 0));
    expect(st.circuit.wires, isEmpty);

    st.linkTap(const GridPoint(50, -10));
    expect(st.linkAnchor, isNull);
    expect(st.circuit.wires, hasLength(1));
    // Sai da origem pelo eixo do componente (leste): horizontal primeiro.
    expect(st.circuit.wires.single.points,
        const [GridPoint(0, 0), GridPoint(50, 0), GridPoint(50, -10)]);
  });

  test('tocar no corpo do componente escolhe a primeira entrada livre', () {
    final st = _cenario();
    addTearDown(st.dispose);

    st.linkTap(const GridPoint(0, 0));
    st.linkTap(const GridPoint(80, 0)); // corpo do AND, longe dos terminais
    expect(st.circuit.wires.single.end, const GridPoint(50, -10));

    // Com a primeira entrada ocupada, a ligação seguinte vai para a outra.
    st.linkTap(const GridPoint(0, 0));
    st.linkTap(const GridPoint(80, 0));
    expect(st.circuit.wires.last.end, const GridPoint(50, 10));
  });

  test('toque no vazio cancela a ligação em andamento', () {
    final st = _cenario();
    addTearDown(st.dispose);

    st.linkTap(const GridPoint(0, 0));
    st.linkTap(const GridPoint(400, 400));
    expect(st.linkAnchor, isNull);
    expect(st.circuit.wires, isEmpty);
  });

  test('tocar duas vezes no mesmo terminal desiste', () {
    final st = _cenario();
    addTearDown(st.dispose);

    st.linkTap(const GridPoint(0, 0));
    st.linkTap(const GridPoint(0, 0));
    expect(st.linkAnchor, isNull);
    expect(st.circuit.wires, isEmpty);
  });

  test('trocar de ferramenta limpa a origem marcada', () {
    final st = _cenario();
    addTearDown(st.dispose);

    st.linkTap(const GridPoint(0, 0));
    st.setMode(EditorMode.select);
    expect(st.linkAnchor, isNull);
  });

  test('tocar na saída do destino escorrega para uma entrada livre', () {
    final st = _cenario();
    addTearDown(st.dispose);

    st.linkTap(const GridPoint(0, 0));
    st.linkTap(const GridPoint(100, 0)); // saída do AND, em cima do terminal
    expect(st.circuit.wires.single.end, const GridPoint(50, -10));
  });

  testWidgets('no modo Fio, dois toques no canvas ligam os componentes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LogiSnapApp());
    await tester.pump();

    final canvas = tester.getRect(find.byType(CircuitCanvas));
    const primeiro = Offset(150, 150);
    const segundo = Offset(450, 150);

    Future<void> colocar(String tipo, Offset onde) async {
      await tester.tap(find.widgetWithText(ChoiceChip, tipo));
      await tester.pump();
      await tester.tapAt(canvas.topLeft + onde);
      await tester.pump();
    }

    await colocar('Entrada', primeiro);
    await colocar('Saída', segundo);

    await tester.tap(find.text('Fio'));
    await tester.pump();
    await tester.tapAt(canvas.topLeft + primeiro);
    await tester.pump();
    await tester.tapAt(canvas.topLeft + segundo);
    await tester.pump();

    final circuit = _painter(tester).circuit;
    expect(circuit.components, hasLength(2));
    expect(circuit.wires, hasLength(1));
    expect(circuit.wires.single.points,
        const [GridPoint(60, 40), GridPoint(240, 40)]);
  });

  group('a ligação não pode criar curto', () {
    // Duas entradas ligadas em ordem "de baixo para cima": o L do segundo fio
    // não pode passar por cima da entrada já usada — foi assim que um AND com
    // 1 e 0 nas entradas acabava todo vermelho.
    test('cada pino cai na entrada mais alinhada com ele', () {
      final st = EditorState();
      addTearDown(st.dispose);
      final um = st.circuit.addComponent(Component(
          id: st.circuit.newId(), type: ComponentType.inputPin, x: 0, y: 0)
        ..state = LogicValue.one);
      final zero = st.circuit.addComponent(Component(
          id: st.circuit.newId(), type: ComponentType.inputPin, x: 0, y: 40)
        ..state = LogicValue.zero);
      final and = st.circuit.addComponent(Component(
        id: st.circuit.newId(),
        type: ComponentType.andGate,
        x: 100,
        y: 20,
        inputs: 2,
      ));

      // O pino de baixo liga primeiro, tocando no corpo da porta.
      st.linkTap(zero.location);
      st.linkTap(const GridPoint(80, 20));
      expect(st.circuit.wires.single.end, const GridPoint(50, 30));

      st.linkTap(um.location);
      st.linkTap(const GridPoint(80, 20));
      expect(st.circuit.wires.last.end, const GridPoint(50, 10));

      expect(st.simulator.valueOfPort(and, 1), LogicValue.one);
      expect(st.simulator.valueOfPort(and, 2), LogicValue.zero);
      expect(st.simulator.valueOfPort(and, 0), LogicValue.zero);
    });

    test('sobrando só a entrada mais longe, o fio desvia pelo outro eixo', () {
      final st = EditorState();
      addTearDown(st.dispose);
      final and = st.circuit.addComponent(Component(
        id: st.circuit.newId(),
        type: ComponentType.andGate,
        x: 100,
        y: 20,
        inputs: 3,
      ));
      // Entradas em (50,10), (50,20) e (50,30); as duas primeiras já ocupadas.
      st.circuit.addWirePath(const [GridPoint(20, 10), GridPoint(50, 10)]);
      st.circuit.addWirePath(const [GridPoint(20, 20), GridPoint(50, 20)]);

      final pino = st.circuit.addComponent(Component(
          id: st.circuit.newId(), type: ComponentType.inputPin, x: 0, y: 0));
      st.linkTap(pino.location);
      st.linkTap(const GridPoint(80, 20));

      final novo = st.circuit.wires.last;
      expect(novo.end, const GridPoint(50, 30));
      // Vertical primeiro: o L horizontal encostaria nas outras duas entradas.
      expect(novo.points,
          const [GridPoint(0, 0), GridPoint(0, 30), GridPoint(50, 30)]);
      for (final p in and.ports.where((p) => !p.isOutput)) {
        if (p.location == novo.end) continue;
        expect(novo.contains(p.location), isFalse,
            reason: 'o fio novo encostou em ${p.location}');
      }
    });
  });
}
