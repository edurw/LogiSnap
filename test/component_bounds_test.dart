import 'package:flutter_test/flutter_test.dart';
import 'package:logisnap/core/circuit.dart';
import 'package:logisnap/core/component.dart';
import 'package:logisnap/core/geometry.dart';

Component place(
  Circuit c,
  ComponentType type, {
  int x = 100,
  int y = 100,
  Facing facing = Facing.east,
  int? inputs,
}) =>
    c.addComponent(Component(
      id: c.newId(),
      type: type,
      x: x,
      y: y,
      facing: facing,
      inputs: inputs,
    ));

void main() {
  group('Os limites do componente são o corpo desenhado', () {
    test('pino de entrada: caixa de 20x20 atrás da âncora', () {
      final circuit = Circuit();
      final pin = place(circuit, ComponentType.inputPin);
      expect(circuit.boundsOf(pin), [80, 90, 100, 110]);
    });

    test('pino de saída: mesma caixa do círculo desenhado', () {
      final circuit = Circuit();
      final pin = place(circuit, ComponentType.outputPin);
      expect(circuit.boundsOf(pin), [80, 90, 100, 110]);
    });

    test('AND de 2 entradas: 50 de corpo por 40 de altura', () {
      final circuit = Circuit();
      final gate = place(circuit, ComponentType.andGate, x: 200, inputs: 2);
      expect(gate.axisLength, 50);
      expect(gate.bodyHalfHeight, 20);
      expect(circuit.boundsOf(gate), [150, 80, 200, 120]);
    });

    test('a caixa acompanha a rotação', () {
      final circuit = Circuit();
      final gate = place(circuit, ComponentType.andGate,
          x: 200, inputs: 2, facing: Facing.north);
      expect(circuit.boundsOf(gate), [180, 100, 220, 150]);
    });

    test('mais entradas alargam a caixa junto com o corpo', () {
      final circuit = Circuit();
      final gate = place(circuit, ComponentType.andGate, inputs: 5);
      expect(gate.bodyHalfHeight, 30);
      expect(circuit.boundsOf(gate), [50, 70, 100, 130]);
      // Nenhuma entrada fica de fora da caixa.
      for (final p in gate.ports) {
        expect(p.location.y, inInclusiveRange(70, 130));
        expect(p.location.x, inInclusiveRange(50, 100));
      }
    });

    test('NOT: triângulo estreito, não a caixa das portas grandes', () {
      final circuit = Circuit();
      final gate = place(circuit, ComponentType.notGate);
      expect(circuit.boundsOf(gate), [70, 90, 100, 110]);
    });

    test('XOR inclui o arco extra de trás', () {
      final circuit = Circuit();
      final gate = place(circuit, ComponentType.xorGate, inputs: 2);
      expect(gate.axisLength, 60);
      expect(circuit.boundsOf(gate), [40, 80, 100, 120]);
    });
  });

  group('Área de toque', () {
    test('o toque pega o componente com folga pequena, e nada além', () {
      final circuit = Circuit();
      final pin = place(circuit, ComponentType.inputPin);
      // Dentro do corpo.
      expect(circuit.componentAt(const GridPoint(90, 100), tolerance: 4)?.id,
          pin.id);
      // Na folga.
      expect(circuit.componentAt(const GridPoint(104, 100), tolerance: 4)?.id,
          pin.id);
      // Fora dela.
      expect(circuit.componentAt(const GridPoint(105, 100), tolerance: 4),
          isNull);
      expect(circuit.componentAt(const GridPoint(100, 115), tolerance: 4),
          isNull);
    });

    test('dois pinos vizinhos não disputam o mesmo toque', () {
      final circuit = Circuit();
      final a = place(circuit, ComponentType.inputPin, x: 100, y: 100);
      final b = place(circuit, ComponentType.inputPin, x: 100, y: 140);
      expect(
          circuit.componentAt(const GridPoint(90, 100), tolerance: 4)?.id, a.id);
      expect(circuit.componentAt(const GridPoint(90, 140), tolerance: 4)?.id,
          b.id);
      // O vão entre os dois não pertence a nenhum.
      expect(
          circuit.componentAt(const GridPoint(90, 120), tolerance: 4), isNull);
    });
  });
}
