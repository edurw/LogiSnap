import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logisnap/core/circ_format.dart';
import 'package:logisnap/core/circuit.dart';
import 'package:logisnap/core/component.dart';
import 'package:logisnap/core/geometry.dart';
import 'package:logisnap/core/serialization.dart';
import 'package:logisnap/core/wire.dart';

void main() {
  group('O fio é um objeto só', () {
    test('um traço em L vira um único fio com curva', () {
      final circuit = Circuit();
      final w = circuit.addRoutedWire(
        const GridPoint(0, 0),
        const GridPoint(100, 50),
      );
      expect(circuit.wires, hasLength(1));
      expect(w!.points, [
        const GridPoint(0, 0),
        const GridPoint(100, 0),
        const GridPoint(100, 50),
      ]);
      expect(w.segmentCount, 2);
      expect(w.hasCorners, isTrue);
    });

    test('apagar remove o caminho inteiro, não só um trecho', () {
      final circuit = Circuit();
      circuit.addRoutedWire(const GridPoint(0, 0), const GridPoint(100, 50));
      // Toque sobre o trecho vertical, longe do ponto inicial.
      final hit = circuit.wireAt(const GridPoint(100, 30), tolerance: 8);
      expect(hit, isNotNull);
      circuit.removeWire(hit!);
      expect(circuit.wires, isEmpty);
    });

    test('mover desloca o caminho inteiro', () {
      final circuit = Circuit();
      final w =
          circuit.addRoutedWire(const GridPoint(0, 0), const GridPoint(100, 50))!;
      circuit.replaceWire(w.translated(20, -10));
      expect(circuit.wires.single.points, [
        const GridPoint(20, -10),
        const GridPoint(120, -10),
        const GridPoint(120, 40),
      ]);
      expect(circuit.wires.single.id, w.id, reason: 'o fio continua o mesmo');
    });

    test('a curva é meio de caminho, não uma ponta', () {
      // Só as pontas conectam com outros fios; a curva é um ponto interno.
      // É isso que impede o roteamento em L de criar ligações por acidente,
      // como acontecia quando o L virava dois fios independentes.
      final w = Wire(1, const [
        GridPoint(0, 0),
        GridPoint(100, 0),
        GridPoint(100, 50),
      ]);
      expect(w.endpoints, const [GridPoint(0, 0), GridPoint(100, 50)]);
      expect(w.contains(const GridPoint(100, 0)), isTrue);
      expect(w.containsInterior(const GridPoint(100, 0)), isTrue);
    });
  });

  group('Conexões entre fios', () {
    test('fios sobrepostos pelo meio não se juntam', () {
      final circuit = Circuit();
      // Dois caminhos que compartilham 100 unidades da mesma coluna x=200,
      // mas sem que nenhuma ponta encoste no outro fio.
      circuit.addWirePath(const [
        GridPoint(0, 0),
        GridPoint(200, 0),
        GridPoint(200, 200),
      ]);
      circuit.addWirePath(const [
        GridPoint(0, 100),
        GridPoint(200, 100),
        GridPoint(200, -100),
      ]);
      final netlist = circuit.buildNetlist();
      expect(
        netlist.wireNets[circuit.wires[0].id],
        isNot(netlist.wireNets[circuit.wires[1].id]),
        reason: 'circuitos diferentes passando um por cima do outro',
      );
    });

    test('cruzamento simples não conecta', () {
      final circuit = Circuit();
      circuit.addWire(const GridPoint(0, 50), const GridPoint(100, 50));
      circuit.addWire(const GridPoint(50, 0), const GridPoint(50, 100));
      final netlist = circuit.buildNetlist();
      expect(
        netlist.wireNets[circuit.wires[0].id],
        isNot(netlist.wireNets[circuit.wires[1].id]),
      );
    });

    test('ponta encostando em outro fio faz a derivação em T', () {
      final circuit = Circuit();
      circuit.addWire(const GridPoint(0, 50), const GridPoint(100, 50));
      circuit.addWire(const GridPoint(50, 50), const GridPoint(50, 150));
      final netlist = circuit.buildNetlist();
      expect(
        netlist.wireNets[circuit.wires[0].id],
        netlist.wireNets[circuit.wires[1].id],
      );
    });

    test('porta de componente sobre o caminho conecta', () {
      final circuit = Circuit();
      final pin = circuit.addComponent(Component(
        id: circuit.newId(),
        type: ComponentType.inputPin,
        x: 50,
        y: 0,
      ));
      final w = circuit.addWirePath(const [
        GridPoint(0, 0),
        GridPoint(100, 0),
        GridPoint(100, 100),
      ])!;
      final netlist = circuit.buildNetlist();
      expect(netlist.portNets[(pin.id, 0)], netlist.wireNets[w.id]);
    });
  });

  group('Persistência', () {
    test('JSON preserva o caminho e o id do fio', () {
      final circuit = Circuit();
      final w =
          circuit.addRoutedWire(const GridPoint(0, 0), const GridPoint(100, 50))!;
      final decoded = CircuitJson.decode(CircuitJson.encode(circuit));
      expect(decoded.wires, hasLength(1));
      expect(decoded.wires.single.id, w.id);
      expect(decoded.wires.single.points, w.points);
    });

    test('JSON do formato 1 (segmentos retos) ainda abre', () {
      // O carimbo "app" é de propósito o nome antigo: um projeto salvo antes
      // do rename para LogiSnap tem de continuar abrindo. O decodificador
      // ignora esse campo, então ele só documenta a origem do arquivo.
      const legacy = '''
{
  "app": "logisim_mobile",
  "version": 1,
  "name": "antigo",
  "components": [],
  "wires": [{"x1": 0, "y1": 0, "x2": 100, "y2": 0}]
}
''';
      final circuit = CircuitJson.decode(legacy);
      expect(circuit.wires, hasLength(1));
      expect(circuit.wires.single.points,
          const [GridPoint(0, 0), GridPoint(100, 0)]);
    });

    test('.circ: segmentos encadeados voltam como um fio só', () {
      final xml =
          File('assets/examples/meia_somadora.circ').readAsStringSync();
      final circuit = CircFormat.import(xml).circuit;
      // O arquivo tem 10 <wire>; os encadeados viram caminhos únicos.
      expect(circuit.wires.length, lessThan(10));
      expect(circuit.wires.any((w) => w.hasCorners), isTrue);
      // Nenhuma junção em T foi fundida por engano: a derivação em (220,180)
      // continua sendo ponta de um fio sobre o meio de outro.
      final tronco = circuit.wires
          .firstWhere((w) => w.contains(const GridPoint(160, 180)));
      final ramo = circuit.wires.firstWhere(
          (w) => w.endpoints.contains(const GridPoint(220, 180)));
      expect(identical(tronco, ramo), isFalse);
    });
  });

  group('Normalização do caminho', () {
    test('funde trechos colineares e descarta repetidos', () {
      final w = Wire(1, const [
        GridPoint(0, 0),
        GridPoint(50, 0),
        GridPoint(50, 0),
        GridPoint(100, 0),
        GridPoint(100, 40),
      ]);
      expect(w.points, const [
        GridPoint(0, 0),
        GridPoint(100, 0),
        GridPoint(100, 40),
      ]);
    });

    test('distanceTo mede a distância até o traço', () {
      final w = Wire(1, const [GridPoint(0, 0), GridPoint(100, 0)]);
      expect(w.distanceTo(const GridPoint(50, 0)), 0);
      expect(w.distanceTo(const GridPoint(50, 6)), 6);
      expect(w.distanceTo(const GridPoint(-10, 0)), 10);
    });
  });
}
