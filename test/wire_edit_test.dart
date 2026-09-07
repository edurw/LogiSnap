import 'package:flutter_test/flutter_test.dart';
import 'package:logisnap/core/circuit.dart';
import 'package:logisnap/core/component.dart';
import 'package:logisnap/core/geometry.dart';
import 'package:logisnap/core/wire.dart';

/// Todo resultado de edição tem de continuar ortogonal.
///
/// [Wire.normalizePath] descarta em silêncio um ponto que formaria diagonal,
/// então um ponto sumindo seria um bug difícil de perceber sem esta checagem.
void expectOrtogonal(Wire w) {
  for (final (a, b) in w.segments) {
    expect(a.x == b.x || a.y == b.y, isTrue,
        reason: 'trecho $a -> $b não é horizontal nem vertical em $w');
    expect(a == b, isFalse, reason: 'trecho de comprimento zero em $w');
  }
}

/// L clássico: horizontal de (0,0) a (100,0), depois vertical até (100,50).
Wire umL() => Wire(1, const [
      GridPoint(0, 0),
      GridPoint(100, 0),
      GridPoint(100, 50),
    ]);

void main() {
  group('Roteamento na criação', () {
    test('a dica de eixo dá dois caminhos para o mesmo par de pontos', () {
      const from = GridPoint(0, 0);
      const to = GridPoint(100, 60);

      expect(
        Wire.routePath(from, to, firstAxis: RouteAxis.horizontal),
        const [GridPoint(0, 0), GridPoint(100, 0), GridPoint(100, 60)],
      );
      expect(
        Wire.routePath(from, to, firstAxis: RouteAxis.vertical),
        const [GridPoint(0, 0), GridPoint(0, 60), GridPoint(100, 60)],
      );
    });

    test('sem dica, mantém o eixo dominante de sempre', () {
      // dx (100) > dy (60): horizontal primeiro.
      expect(
        Wire.routePath(const GridPoint(0, 0), const GridPoint(100, 60)),
        const [GridPoint(0, 0), GridPoint(100, 0), GridPoint(100, 60)],
      );
      // dy (100) > dx (60): vertical primeiro.
      expect(
        Wire.routePath(const GridPoint(0, 0), const GridPoint(60, 100)),
        const [GridPoint(0, 0), GridPoint(0, 100), GridPoint(60, 100)],
      );
    });

    test('a dica não inventa curva em caminho reto', () {
      expect(
        Wire.routePath(const GridPoint(0, 0), const GridPoint(100, 0),
            firstAxis: RouteAxis.vertical),
        const [GridPoint(0, 0), GridPoint(100, 0)],
      );
    });
  });

  group('Arrastar uma curva', () {
    test('a curva para no ponto pedido e as pontas não se mexem', () {
      final w = umL();
      final edited = w.moveVertex(1, const GridPoint(60, 30));

      expectOrtogonal(edited);
      expect(edited.contains(const GridPoint(60, 30)), isTrue,
          reason: 'a curva tem de passar por onde o dedo parou');
      expect(edited.start, w.start);
      expect(edited.end, w.end);
      expect(edited.points, const [
        GridPoint(0, 0),
        GridPoint(0, 30),
        GridPoint(60, 30),
        GridPoint(60, 50),
        GridPoint(100, 50),
      ]);
    });

    test('empurradas de volta para a linha, as curvas somem', () {
      // Ida e volta: fio reto -> arrasta o meio -> Z -> empurra de volta.
      final reto = Wire(1, const [GridPoint(0, 0), GridPoint(100, 0)]);
      final z = reto.slideSegment(0, const GridPoint(50, 40));
      expect(z.points, hasLength(4));

      final devolvido = z.slideSegment(1, const GridPoint(50, 0));
      expectOrtogonal(devolvido);
      expect(devolvido.points, reto.points,
          reason: 'normalizePath funde os colineares e as curvas somem');
    });

    test('o id do fio sobrevive à edição', () {
      expect(umL().moveVertex(1, const GridPoint(60, 30)).id, 1);
    });
  });

  group('Arrastar uma ponta', () {
    test('a ponta vai para onde o dedo mandou e a outra fica', () {
      final w = umL();
      final edited = w.moveVertex(0, const GridPoint(0, 30));

      expectOrtogonal(edited);
      expect(edited.start, const GridPoint(0, 30));
      expect(edited.end, w.end, reason: 'a outra ponta não se mexe');
      expect(edited.points, const [
        GridPoint(0, 30),
        GridPoint(100, 30),
        GridPoint(100, 50),
      ]);
    });

    test('num fio reto, a outra ponta é preservada por um conector', () {
      final reto = Wire(1, const [GridPoint(0, 0), GridPoint(100, 0)]);
      final edited = reto.moveVertex(0, const GridPoint(20, 30));

      expectOrtogonal(edited);
      expect(edited.start, const GridPoint(20, 30));
      expect(edited.end, const GridPoint(100, 0),
          reason: 'a ponta vizinha não pode andar de tabela');
    });

    test('arrastar a última ponta funciona igual', () {
      final w = umL();
      final edited = w.moveVertex(w.points.length - 1, const GridPoint(140, 50));
      expectOrtogonal(edited);
      expect(edited.end, const GridPoint(140, 50));
      expect(edited.start, w.start);
    });
  });

  group('Arrastar o meio de um trecho', () {
    test('num fio reto nasce um Z, com as duas pontas paradas', () {
      final reto = Wire(1, const [GridPoint(0, 0), GridPoint(100, 0)]);
      final edited = reto.slideSegment(0, const GridPoint(50, 40));

      expectOrtogonal(edited);
      expect(edited.points, const [
        GridPoint(0, 0),
        GridPoint(0, 40),
        GridPoint(100, 40),
        GridPoint(100, 0),
      ]);
      expect(edited.start, reto.start);
      expect(edited.end, reto.end);
    });

    test('no trecho do meio de um Z, só ele anda', () {
      final z = Wire(1, const [
        GridPoint(0, 0),
        GridPoint(50, 0),
        GridPoint(50, 40),
        GridPoint(100, 40),
      ]);
      final edited = z.slideSegment(1, const GridPoint(80, 20));

      expectOrtogonal(edited);
      expect(edited.points, const [
        GridPoint(0, 0),
        GridPoint(80, 0),
        GridPoint(80, 40),
        GridPoint(100, 40),
      ]);
      expect(edited.points.length, z.points.length);
    });

    test('o arraste só vale no eixo perpendicular ao trecho', () {
      final reto = Wire(1, const [GridPoint(0, 0), GridPoint(100, 0)]);
      // Trecho horizontal: mexer só em x não muda nada.
      expect(reto.slideSegment(0, const GridPoint(70, 0)).points, reto.points);
    });
  });

  group('Idempotência do arraste', () {
    test('repetir a operação a partir da mesma base dá sempre o mesmo fio', () {
      // O caso do índice deslocando: moveVertex e slideSegment inserem pontos,
      // então aplicar em cima do resultado anterior mexeria na alça errada.
      final base = umL();
      final destinos = [
        const GridPoint(60, 30),
        const GridPoint(40, 20),
        const GridPoint(80, 10),
      ];
      for (final destino in destinos) {
        final uma = base.moveVertex(1, destino);
        final outra = base.moveVertex(1, destino);
        expect(uma.points, outra.points);
        expectOrtogonal(uma);
        expect(uma.start, base.start);
        expect(uma.end, base.end);
      }
    });

    test('índices fora do caminho não fazem nada', () {
      final w = umL();
      expect(w.moveVertex(-1, const GridPoint(0, 0)).points, w.points);
      expect(w.moveVertex(9, const GridPoint(0, 0)).points, w.points);
      expect(w.slideSegment(9, const GridPoint(0, 0)).points, w.points);
    });
  });

  group('Alças', () {
    test('um vértice por ponto e um ponto médio por trecho', () {
      final w = umL();
      final vertices = w.handles.where((h) => !h.isSegment).toList();
      final meios = w.handles.where((h) => h.isSegment).toList();

      expect(vertices.map((h) => h.at), w.points);
      expect(meios, hasLength(w.segmentCount));
      expect(meios.first.at, const GridPoint(50, 0));
      expect(meios.last.at, const GridPoint(100, 25));
    });

    test('segmentIndexAt acerta o trecho certo', () {
      final w = umL();
      expect(w.segmentIndexAt(const GridPoint(50, 2), tolerance: 8), 0);
      expect(w.segmentIndexAt(const GridPoint(98, 40), tolerance: 8), 1);
      expect(w.segmentIndexAt(const GridPoint(0, 200), tolerance: 8), isNull);
    });
  });

  group('Efeito na netlist', () {
    /// Pino em (0,0) ligado por um L à entrada de cima de uma AND.
    (Circuit, Component, Component, Wire) montar() {
      final circuit = Circuit();
      final pin = circuit.addComponent(Component(
          id: circuit.newId(), type: ComponentType.inputPin, x: 0, y: 0));
      final gate = circuit.addComponent(Component(
        id: circuit.newId(),
        type: ComponentType.andGate,
        x: 200,
        y: 100,
        inputs: 2,
      ));
      final entrada = gate.ports[1].location; // (150, 90)
      final w = circuit.addWirePath([
        const GridPoint(0, 0),
        GridPoint(entrada.x, 0),
        entrada,
      ])!;
      return (circuit, pin, gate, w);
    }

    test('mover uma curva não muda as redes', () {
      final (circuit, pin, gate, w) = montar();
      final antes = circuit.buildNetlist();
      final redeAntes = antes.portNets[(pin.id, 0)];
      expect(redeAntes, antes.portNets[(gate.id, 1)],
          reason: 'pino e entrada começam na mesma rede');

      circuit.replaceWire(w.moveVertex(1, const GridPoint(80, 40)));
      final depois = circuit.buildNetlist();
      expectOrtogonal(circuit.wires.single);
      expect(depois.portNets[(pin.id, 0)], depois.portNets[(gate.id, 1)],
          reason: 'a ligação sobrevive à remodelagem');
    });

    test('mover uma ponta para fora da porta desliga o fio', () {
      final (circuit, pin, gate, w) = montar();
      // Puxa para longe a ponta que estava na entrada da porta.
      circuit.replaceWire(
          w.moveVertex(w.points.length - 1, const GridPoint(400, 400)));
      final depois = circuit.buildNetlist();
      expectOrtogonal(circuit.wires.single);
      expect(depois.portNets[(pin.id, 0)],
          isNot(depois.portNets[(gate.id, 1)]),
          reason: 'é a liberdade pretendida: a ponta saiu da porta');
    });

    test('esticar a ponta ao longo da mesma linha mantém a ligação', () {
      final (circuit, pin, gate, w) = montar();
      // A ponta desce, mas o caminho continua passando pela porta em (150,90).
      circuit.replaceWire(
          w.moveVertex(w.points.length - 1, const GridPoint(150, 400)));
      final depois = circuit.buildNetlist();
      expect(depois.portNets[(pin.id, 0)], depois.portNets[(gate.id, 1)],
          reason: 'a porta continua encostada no fio, agora pelo meio dele');
    });
  });
}
