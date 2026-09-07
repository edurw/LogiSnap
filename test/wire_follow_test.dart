import 'package:flutter_test/flutter_test.dart';
import 'package:logisim_mobile/core/component.dart';
import 'package:logisim_mobile/core/geometry.dart';
import 'package:logisim_mobile/core/wire.dart';
import 'package:logisim_mobile/state/editor_state.dart';

import 'wire_edit_test.dart' show expectOrtogonal;

/// Bancada: pino em (0,90) e AND em (200,100). O pino fica na mesma linha da
/// entrada de cima da porta, em (150,90), para [Bancada.ligar] poder usar um
/// fio reto que de fato conecta os dois.
class Bancada {
  final EditorState st;
  final Component pin;
  final Component gate;

  Bancada._(this.st, this.pin, this.gate);

  factory Bancada() {
    final st = EditorState();
    final circuit = st.circuit;
    final pin = circuit.addComponent(Component(
        id: circuit.newId(), type: ComponentType.inputPin, x: 0, y: 90));
    final gate = circuit.addComponent(Component(
      id: circuit.newId(),
      type: ComponentType.andGate,
      x: 200,
      y: 100,
      inputs: 2,
    ));
    return Bancada._(st, pin, gate);
  }

  GridPoint get entrada => gate.ports[1].location;
  Wire get fio => st.circuit.wires.single;

  /// Liga o pino à entrada de cima com um fio reto na horizontal.
  Wire ligar() => st.circuit.addWirePath([
        GridPoint(0, entrada.y),
        entrada,
      ])!;

  void selecionar(Component c) => st.selectedId = c.id;

  void arrastar(Component c, GridPoint para) {
    selecionar(c);
    st.beginMove(GridPoint(c.x, c.y));
    st.moveTo(para);
    st.endMove();
  }

  /// Pino e entrada da porta estão na mesma rede?
  bool get ligados {
    final n = st.circuit.buildNetlist();
    return n.portNets[(pin.id, 0)] == n.portNets[(gate.id, 1)];
  }
}

void main() {
  group('Arrastar o componente', () {
    test('a ponta presa acompanha e a outra fica parada', () {
      final b = Bancada();
      final fio = b.ligar();
      expect(fio.points, const [GridPoint(0, 90), GridPoint(150, 90)]);
      expect(b.ligados, isTrue);

      b.arrastar(b.gate, const GridPoint(200, 140));

      expectOrtogonal(b.fio);
      expect(b.fio.start, const GridPoint(0, 90),
          reason: 'a ponta no pino não se mexe');
      expect(b.fio.end, b.entrada,
          reason: 'a ponta na porta acompanhou o componente');
    });

    test('a ligação sobrevive ao movimento', () {
      final b = Bancada();
      b.ligar();
      b.arrastar(b.gate, const GridPoint(320, 220));
      expect(b.ligados, isTrue);
    });

    test('o traçado feito à mão é preservado', () {
      final b = Bancada();
      // Fio com uma volta deliberada no meio do caminho.
      final fio = b.st.circuit.addWirePath([
        const GridPoint(0, 90),
        const GridPoint(60, 90),
        const GridPoint(60, 20),
        const GridPoint(150, 20),
        b.entrada,
      ])!;
      final voltaOriginal = fio.points.sublist(1, 3);

      b.arrastar(b.gate, const GridPoint(240, 100));

      expectOrtogonal(b.fio);
      expect(b.fio.points.sublist(1, 3), voltaOriginal,
          reason: 'as curvas do meio continuam onde estavam');
      expect(b.fio.end, b.entrada);
      expect(b.ligados, isTrue);
    });

    test('fio solto, longe das portas, não é tocado', () {
      final b = Bancada();
      final solto = b.st.circuit.addWirePath(const [
        GridPoint(500, 500),
        GridPoint(600, 500),
      ])!;
      b.arrastar(b.gate, const GridPoint(300, 300));
      expect(b.st.circuit.wireById(solto.id)!.points, solto.points);
    });

    test('fio com as duas pontas no mesmo componente acompanha inteiro', () {
      final b = Bancada();
      // Da saída da AND de volta para a entrada de baixo.
      final saida = b.gate.ports[0].location;
      final entradaBaixo = b.gate.ports[2].location;
      final fio = b.st.circuit.addWirePath([
        saida,
        GridPoint(saida.x + 40, saida.y),
        GridPoint(saida.x + 40, entradaBaixo.y),
        entradaBaixo,
      ])!;
      expect(fio.points, hasLength(4));

      b.arrastar(b.gate, const GridPoint(260, 160));

      expectOrtogonal(b.fio);
      expect(b.fio.start, b.gate.ports[0].location);
      expect(b.fio.end, b.gate.ports[2].location);
    });

    test('ida e volta devolve o traçado original', () {
      // A propriedade que justifica recalcular a partir da base: se o ajuste
      // fosse incremental, um trecho colapsado no meio do caminho não voltaria.
      final b = Bancada();
      final original = b.ligar().points.toList();

      b.selecionar(b.gate);
      b.st.beginMove(GridPoint(b.gate.x, b.gate.y));
      for (final destino in const [
        GridPoint(200, 0),
        GridPoint(60, 90),
        GridPoint(400, 300),
        GridPoint(200, 100), // de volta ao ponto de partida
      ]) {
        b.st.moveTo(destino);
      }
      b.st.endMove();

      expect(b.fio.points, original);
      expect(b.ligados, isTrue);
    });
  });

  group('Girar e mudar entradas', () {
    test('girar arrasta os fios junto', () {
      final b = Bancada();
      b.ligar();
      b.selecionar(b.gate);

      b.st.rotateSelected();

      expectOrtogonal(b.fio);
      expect(b.fio.end, b.entrada, reason: 'a ponta seguiu a porta girada');
      expect(b.ligados, isTrue);
    });

    test('aumentar o nº de entradas arrasta os fios', () {
      final b = Bancada();
      b.ligar();
      b.selecionar(b.gate);
      final antes = b.entrada;

      b.st.setSelectedInputs(5);

      expect(b.entrada, isNot(antes), reason: 'a porta mudou de lugar');
      expectOrtogonal(b.fio);
      expect(b.fio.end, b.entrada);
      expect(b.ligados, isTrue);
    });

    test('reduzir as entradas não quebra o fio da porta que sumiu', () {
      final b = Bancada();
      b.selecionar(b.gate);
      b.st.setSelectedInputs(5);
      // Liga na última entrada, que vai deixar de existir.
      final ultima = b.gate.ports.last;
      final fio = b.st.circuit.addWirePath([
        GridPoint(0, ultima.location.y),
        ultima.location,
      ])!;

      b.st.setSelectedInputs(2);

      final restante = b.st.circuit.wireById(fio.id)!;
      expectOrtogonal(restante);
      expect(restante.points, fio.points,
          reason: 'sem porta para seguir, o fio fica onde está');
    });
  });

  group('Desfazer', () {
    test('desfaz componente e fios de uma vez', () {
      final b = Bancada();
      final original = b.ligar().points.toList();
      final posicaoOriginal = GridPoint(b.gate.x, b.gate.y);

      b.arrastar(b.gate, const GridPoint(320, 220));
      expect(b.fio.points, isNot(original));

      b.st.undo();

      expect(b.st.circuit.wires.single.points, original);
      final gate = b.st.circuit.components
          .firstWhere((c) => c.type == ComponentType.andGate);
      expect(GridPoint(gate.x, gate.y), posicaoOriginal);
    });
  });
}
