import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logisim_mobile/core/circ_format.dart';
import 'package:logisim_mobile/core/circuit.dart';
import 'package:logisim_mobile/core/component.dart';
import 'package:logisim_mobile/core/geometry.dart';
import 'package:logisim_mobile/core/simulator.dart';
import 'package:logisim_mobile/core/values.dart';

Component find(Circuit c, String label) =>
    c.components.firstWhere((e) => e.label == label);

void main() {
  group('Portas lógicas', () {
    test('tabela-verdade da AND de 2 entradas', () {
      final circuit = Circuit();
      // Porta AND em (100,100): entradas em (50,90) e (50,110).
      final gate = circuit.addComponent(Component(
        id: circuit.newId(),
        type: ComponentType.andGate,
        x: 100,
        y: 100,
        inputs: 2,
      ));
      final a = circuit.addComponent(Component(
          id: circuit.newId(), type: ComponentType.inputPin, x: 50, y: 90));
      final b = circuit.addComponent(Component(
          id: circuit.newId(), type: ComponentType.inputPin, x: 50, y: 110));
      final out = circuit.addComponent(Component(
          id: circuit.newId(), type: ComponentType.outputPin, x: 100, y: 100));

      expect(gate.ports.length, 3);
      expect(gate.ports[1].location, const GridPoint(50, 90));
      expect(gate.ports[2].location, const GridPoint(50, 110));

      final sim = Simulator(circuit);
      final cases = {
        (LogicValue.zero, LogicValue.zero): LogicValue.zero,
        (LogicValue.zero, LogicValue.one): LogicValue.zero,
        (LogicValue.one, LogicValue.zero): LogicValue.zero,
        (LogicValue.one, LogicValue.one): LogicValue.one,
      };
      cases.forEach((input, expected) {
        a.state = input.$1;
        b.state = input.$2;
        sim.propagate();
        expect(sim.displayValueOf(out), expected,
            reason: 'AND(${input.$1}, ${input.$2})');
      });
    });

    test('XOR, NAND, NOR, XNOR e NOT', () {
      for (final spec in [
        (ComponentType.xorGate, [false, true, true, false]),
        (ComponentType.nandGate, [true, true, true, false]),
        (ComponentType.norGate, [true, false, false, false]),
        (ComponentType.xnorGate, [true, false, false, true]),
      ]) {
        final circuit = Circuit();
        final gate = circuit.addComponent(Component(
          id: circuit.newId(),
          type: spec.$1,
          x: 100,
          y: 100,
          inputs: 2,
        ));
        final inA = gate.ports[1].location;
        final inB = gate.ports[2].location;
        final a = circuit.addComponent(Component(
            id: circuit.newId(),
            type: ComponentType.inputPin,
            x: inA.x,
            y: inA.y));
        final b = circuit.addComponent(Component(
            id: circuit.newId(),
            type: ComponentType.inputPin,
            x: inB.x,
            y: inB.y));
        final sim = Simulator(circuit);
        var i = 0;
        for (final (va, vb) in [
          (LogicValue.zero, LogicValue.zero),
          (LogicValue.zero, LogicValue.one),
          (LogicValue.one, LogicValue.zero),
          (LogicValue.one, LogicValue.one),
        ]) {
          a.state = va;
          b.state = vb;
          sim.propagate();
          expect(
            sim.valueOfPort(gate, 0),
            spec.$2[i] ? LogicValue.one : LogicValue.zero,
            reason: '${spec.$1} caso $i',
          );
          i++;
        }
      }

      final circuit = Circuit();
      final notGate = circuit.addComponent(Component(
          id: circuit.newId(), type: ComponentType.notGate, x: 100, y: 100));
      final input = notGate.ports[1].location;
      expect(input, const GridPoint(70, 100));
      final a = circuit.addComponent(Component(
          id: circuit.newId(),
          type: ComponentType.inputPin,
          x: input.x,
          y: input.y,
          state: LogicValue.one));
      a.state = LogicValue.one;
      final sim = Simulator(circuit);
      expect(sim.valueOfPort(notGate, 0), LogicValue.zero);
    });

    test('entradas flutuantes são ignoradas (porta com 5 entradas)', () {
      final circuit = Circuit();
      final gate = circuit.addComponent(Component(
        id: circuit.newId(),
        type: ComponentType.andGate,
        x: 100,
        y: 100,
        inputs: 5,
      ));
      // Liga apenas as duas primeiras entradas.
      final p1 = gate.ports[1].location;
      final p2 = gate.ports[2].location;
      final a = circuit.addComponent(Component(
          id: circuit.newId(), type: ComponentType.inputPin, x: p1.x, y: p1.y));
      final b = circuit.addComponent(Component(
          id: circuit.newId(), type: ComponentType.inputPin, x: p2.x, y: p2.y));
      a.state = LogicValue.one;
      b.state = LogicValue.one;
      final sim = Simulator(circuit);
      expect(sim.valueOfPort(gate, 0), LogicValue.one);
    });
  });

  group('Redes e fios', () {
    test('fios que apenas se cruzam não se conectam; ramo em T conecta', () {
      final circuit = Circuit();
      // Fio horizontal e fio vertical cruzando no interior de ambos.
      circuit.addWire(const GridPoint(0, 50), const GridPoint(100, 50));
      circuit.addWire(const GridPoint(50, 0), const GridPoint(50, 100));
      var netlist = circuit.buildNetlist();
      expect(
        netlist.wireNets[circuit.wires[0].id] !=
            netlist.wireNets[circuit.wires[1].id],
        isTrue,
        reason: 'cruzamento não deve conectar',
      );

      // Ramo em T: extremidade de um fio no meio do outro.
      final circuit2 = Circuit();
      circuit2.addWire(const GridPoint(0, 50), const GridPoint(100, 50));
      circuit2.addWire(const GridPoint(50, 50), const GridPoint(50, 100));
      netlist = circuit2.buildNetlist();
      expect(
        netlist.wireNets[circuit2.wires[0].id],
        netlist.wireNets[circuit2.wires[1].id],
        reason: 'ramo em T deve conectar',
      );
    });

    test('conflito de drivers gera erro', () {
      final circuit = Circuit();
      final a = circuit.addComponent(Component(
          id: circuit.newId(), type: ComponentType.inputPin, x: 0, y: 0));
      final b = circuit.addComponent(Component(
          id: circuit.newId(), type: ComponentType.inputPin, x: 100, y: 0));
      final led = circuit.addComponent(Component(
          id: circuit.newId(), type: ComponentType.led, x: 50, y: 0));
      circuit.addWire(const GridPoint(0, 0), const GridPoint(100, 0));
      a.state = LogicValue.one;
      b.state = LogicValue.zero;
      final sim = Simulator(circuit);
      expect(sim.displayValueOf(led), LogicValue.error);
    });

    test('anel de NOT sem valor definido estabiliza em erro', () {
      // Como no Logisim: entrada flutuante -> NOT produz erro, e o anel
      // permanece estável em erro (fio vermelho), sem oscilar.
      final circuit = Circuit();
      final gate = circuit.addComponent(Component(
          id: circuit.newId(), type: ComponentType.notGate, x: 100, y: 100));
      circuit.addWire(const GridPoint(100, 100), const GridPoint(100, 140));
      circuit.addWire(const GridPoint(70, 140), const GridPoint(100, 140));
      circuit.addWire(const GridPoint(70, 100), const GridPoint(70, 140));
      final sim = Simulator(circuit);
      expect(sim.oscillating, isFalse);
      expect(sim.valueOfPort(gate, 0), LogicValue.error);
    });

    test('realimentação com NAND e entrada 1 é detectada como oscilação', () {
      final circuit = Circuit();
      // NAND em (100,100): entradas em (40,90) e (40,110).
      circuit.addComponent(Component(
        id: circuit.newId(),
        type: ComponentType.nandGate,
        x: 100,
        y: 100,
        inputs: 2,
      ));
      final pin = circuit.addComponent(Component(
          id: circuit.newId(), type: ComponentType.inputPin, x: 40, y: 90));
      pin.state = LogicValue.one;
      circuit.addWire(const GridPoint(100, 100), const GridPoint(100, 140));
      circuit.addWire(const GridPoint(40, 140), const GridPoint(100, 140));
      circuit.addWire(const GridPoint(40, 110), const GridPoint(40, 140));
      final sim = Simulator(circuit);
      expect(sim.oscillating, isTrue);
    });
  });

  group('Circuitos de exemplo', () {
    Circuit load(String name) {
      final xml = File('assets/examples/$name').readAsStringSync();
      final result = CircFormat.import(xml);
      return result.circuit;
    }

    test('meia-somadora calcula soma e carry', () {
      final circuit = load('meia_somadora.circ');
      final a = find(circuit, 'A');
      final b = find(circuit, 'B');
      final s = find(circuit, 'S');
      final c = find(circuit, 'C');
      final sim = Simulator(circuit);

      for (final (va, vb, vs, vc) in [
        (0, 0, 0, 0),
        (0, 1, 1, 0),
        (1, 0, 1, 0),
        (1, 1, 0, 1),
      ]) {
        a.state = va == 1 ? LogicValue.one : LogicValue.zero;
        b.state = vb == 1 ? LogicValue.one : LogicValue.zero;
        sim.propagate();
        expect(sim.oscillating, isFalse);
        expect(sim.displayValueOf(s),
            vs == 1 ? LogicValue.one : LogicValue.zero,
            reason: 'S($va,$vb)');
        expect(sim.displayValueOf(c),
            vc == 1 ? LogicValue.one : LogicValue.zero,
            reason: 'C($va,$vb)');
      }
    });

    test('latch SR memoriza o estado', () {
      final circuit = load('latch_sr.circ');
      final s = find(circuit, 'S');
      final r = find(circuit, 'R');
      final q = find(circuit, 'Q');
      final sim = Simulator(circuit);

      // Set
      s.state = LogicValue.one;
      sim.propagate();
      expect(sim.displayValueOf(q), LogicValue.one);
      s.state = LogicValue.zero;
      sim.propagate();
      expect(sim.displayValueOf(q), LogicValue.one, reason: 'memória após S');

      // Reset
      r.state = LogicValue.one;
      sim.propagate();
      expect(sim.displayValueOf(q), LogicValue.zero);
      r.state = LogicValue.zero;
      sim.propagate();
      expect(sim.displayValueOf(q), LogicValue.zero, reason: 'memória após R');
    });

    test('clock alterna o LED pelo NOT', () {
      final circuit = load('pisca_clock.circ');
      final led = find(circuit, 'LED');
      final direct = find(circuit, 'CLK_direto');
      final sim = Simulator(circuit);
      final before = sim.displayValueOf(led);
      expect(before, sim.displayValueOf(direct).not);
      sim.tickClocks();
      expect(sim.displayValueOf(led), before.not);
    });
  });
}
