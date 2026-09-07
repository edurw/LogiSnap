import 'component.dart';
import 'geometry.dart';
import 'wire.dart';

/// O circuito: componentes + fios, e a construção da netlist.
class Circuit {
  String name;
  final List<Component> components = [];
  final List<Wire> wires = [];
  int _nextId = 1;

  Circuit({this.name = 'principal'});

  /// Componentes e fios compartilham o mesmo contador de ids.
  int newId() => _nextId++;

  void registerId(int id) {
    if (id >= _nextId) _nextId = id + 1;
  }

  Component addComponent(Component c) {
    registerId(c.id);
    components.add(c);
    return c;
  }

  void removeComponent(Component c) => components.remove(c);

  // ---------------------------------------------------------------- Fios

  /// Adiciona um fio a partir de um caminho ortogonal. O caminho inteiro vira
  /// um único objeto, com curvas ou sem.
  ///
  /// Retorna null se o caminho for degenerado ou se já existir um fio idêntico.
  Wire? addWirePath(List<GridPoint> points, {int? id}) {
    final path = Wire.normalizePath(points);
    if (path.length < 2) return null;
    final w = Wire(id ?? newId(), path);
    if (id != null) registerId(id);
    for (final existing in wires) {
      if (existing.samePath(w)) return null;
    }
    wires.add(w);
    return w;
  }

  /// Fio de um único segmento reto (usado pela importação e pelos testes).
  Wire? addWire(GridPoint a, GridPoint b) => addWirePath([a, b]);

  /// Fio roteado em "L" entre dois pontos (o traço do editor). [firstAxis] diz
  /// por qual eixo o caminho começa; sem ela, vale o eixo dominante.
  Wire? addRoutedWire(GridPoint from, GridPoint to, {RouteAxis? firstAxis}) =>
      addWirePath(Wire.routePath(from, to, firstAxis: firstAxis));

  void removeWire(Wire w) => wires.removeWhere((e) => e.id == w.id);

  Wire? wireById(int id) {
    for (final w in wires) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Substitui um fio pelo mesmo id (usado ao arrastar um fio).
  void replaceWire(Wire w) {
    final i = wires.indexWhere((e) => e.id == w.id);
    if (i >= 0) wires[i] = w;
  }

  /// Fio mais próximo de [p] dentro de [tolerance].
  Wire? wireAt(GridPoint p, {int tolerance = 0}) {
    Wire? best;
    var bestDist = 1 << 30;
    for (final w in wires) {
      final d = w.distanceTo(p);
      if (d <= tolerance && d < bestDist) {
        bestDist = d;
        best = w;
      }
    }
    return best;
  }

  /// Funde fios encadeados em caminhos únicos.
  ///
  /// Só funde quando os dois fios se encontram em um ponto onde mais nada
  /// toca: exatamente duas pontas de fio ali, nenhum outro fio passando pelo
  /// ponto e nenhuma porta de componente nele. Assim a conectividade é
  /// preservada (junções em T continuam junções) e um fio importado do
  /// Logisim, que vem quebrado em vários segmentos, vira um objeto só.
  void mergeWirePaths() {
    var merged = true;
    while (merged) {
      merged = false;
      for (var i = 0; i < wires.length && !merged; i++) {
        for (var j = i + 1; j < wires.length && !merged; j++) {
          final a = wires[i], b = wires[j];
          final joint = _sharedJoint(a, b);
          if (joint == null) continue;
          if (!_isFreeJoint(joint, a, b)) continue;
          final path = _concatAt(a, b, joint);
          if (path == null) continue;
          wires[i] = Wire(a.id, path);
          wires.removeAt(j);
          merged = true;
        }
      }
    }
  }

  /// Único ponto em que as pontas de [a] e [b] coincidem, ou null.
  GridPoint? _sharedJoint(Wire a, Wire b) {
    final shared = <GridPoint>{};
    for (final pa in a.endpoints) {
      for (final pb in b.endpoints) {
        if (pa == pb) shared.add(pa);
      }
    }
    return shared.length == 1 ? shared.first : null;
  }

  bool _isFreeJoint(GridPoint joint, Wire a, Wire b) {
    var ends = 0;
    for (final w in wires) {
      for (final e in w.endpoints) {
        if (e == joint) ends++;
      }
      final isPair = identical(w, a) || identical(w, b);
      if (!isPair && w.contains(joint)) return false;
    }
    if (ends != 2) return false;
    for (final c in components) {
      for (final port in c.ports) {
        if (port.location == joint) return false;
      }
    }
    return true;
  }

  /// Concatena os caminhos de [a] e [b] passando por [joint].
  List<GridPoint>? _concatAt(Wire a, Wire b, GridPoint joint) {
    final pa = a.end == joint
        ? a.points.toList()
        : (a.start == joint ? a.points.reversed.toList() : null);
    final pb = b.start == joint
        ? b.points.toList()
        : (b.end == joint ? b.points.reversed.toList() : null);
    if (pa == null || pb == null) return null;
    return [...pa, ...pb.skip(1)];
  }

  // ---------------------------------------------------------- Componentes

  /// Componente cujo corpo (mais [tolerance] de folga) contém [p].
  Component? componentAt(GridPoint p, {int tolerance = 0}) {
    Component? best;
    var bestDist = 1 << 30;
    for (final c in components) {
      final b = boundsOf(c);
      if (p.x >= b[0] - tolerance &&
          p.x <= b[2] + tolerance &&
          p.y >= b[1] - tolerance &&
          p.y <= b[3] + tolerance) {
        final cx = (b[0] + b[2]) ~/ 2;
        final cy = (b[1] + b[3]) ~/ 2;
        final d = (p.x - cx).abs() + (p.y - cy).abs();
        if (d < bestDist) {
          bestDist = d;
          best = c;
        }
      }
    }
    return best;
  }

  /// Retângulo [minX, minY, maxX, maxY] do componente — o corpo que é
  /// desenhado, sem folga.
  ///
  /// É o que define tanto o retângulo de seleção quanto a área de toque, então
  /// fica colado no desenho: da âncora até [Component.bodyDepth] para trás, e
  /// [Component.bodyHalfHeight] para cada lado.
  List<int> boundsOf(Component c) {
    final depth = c.bodyDepth;
    final half = c.bodyHalfHeight;
    var minX = c.x, minY = c.y, maxX = c.x, maxY = c.y;

    void include(int x, int y) {
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    for (final (dx, dy) in [
      (0, -half),
      (0, half),
      (-depth, -half),
      (-depth, half),
    ]) {
      final d = c.facing.rotate(dx, dy);
      include(c.x + d.x, c.y + d.y);
    }
    // As portas ficam dentro do corpo, mas garante que nenhuma sobre de fora.
    for (final p in c.ports) {
      include(p.location.x, p.location.y);
    }
    return [minX, minY, maxX, maxY];
  }

  // ------------------------------------------------------------- Netlist

  /// Constrói as redes elétricas.
  ///
  /// Regras:
  /// - um fio é um condutor único: todos os pontos do seu caminho, curvas
  ///   inclusive, pertencem à mesma rede;
  /// - uma **ponta** de fio encostada em outro fio (na ponta dele ou no meio
  ///   dele) liga os dois — é assim que se faz uma derivação em T;
  /// - uma porta de componente que caia sobre o caminho de um fio liga-se a
  ///   ele;
  /// - dois fios que apenas se cruzam ou se sobrepõem pelo meio, sem que
  ///   nenhuma ponta encoste, **não** se conectam. Passar um fio por cima do
  ///   outro não junta as redes.
  Netlist buildNetlist() {
    final parent = <GridPoint, GridPoint>{};

    GridPoint find(GridPoint p) {
      var root = parent.putIfAbsent(p, () => p);
      while (root != parent[root]) {
        root = parent[root]!;
      }
      // compressão de caminho
      var cur = p;
      while (parent[cur] != root) {
        final next = parent[cur]!;
        parent[cur] = root;
        cur = next;
      }
      return root;
    }

    void union(GridPoint a, GridPoint b) {
      final ra = find(a), rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    // O fio inteiro é um condutor só.
    for (final w in wires) {
      union(w.start, w.end);
    }

    // Portas de componente sobre o caminho de um fio.
    for (final w in wires) {
      for (final c in components) {
        for (final port in c.ports) {
          if (w.contains(port.location)) union(w.start, port.location);
        }
      }
    }

    // Pontas de fio encostando em outro fio.
    for (final w in wires) {
      for (final other in wires) {
        if (identical(other, w)) continue;
        for (final e in w.endpoints) {
          if (other.contains(e)) union(other.start, e);
        }
      }
    }

    // Mapeia raiz -> id de rede.
    final netIds = <GridPoint, int>{};
    var nextNet = 0;
    int netOf(GridPoint p) {
      final root = find(p);
      return netIds.putIfAbsent(root, () => nextNet++);
    }

    final portNets = <(int, int), int>{}; // (componentId, portIndex) -> netId
    for (final c in components) {
      for (final p in c.ports) {
        portNets[(c.id, p.index)] = netOf(p.location);
      }
    }

    final wireNets = <int, int>{}; // id do fio -> netId
    for (final w in wires) {
      wireNets[w.id] = netOf(w.start);
    }

    return Netlist(
      netCount: nextNet,
      portNets: portNets,
      wireNets: wireNets,
    );
  }

  void clear() {
    components.clear();
    wires.clear();
    _nextId = 1;
  }
}

class Netlist {
  final int netCount;

  /// (id do componente, índice da porta) -> id da rede.
  final Map<(int, int), int> portNets;

  /// id do fio -> id da rede.
  final Map<int, int> wireNets;

  Netlist({
    required this.netCount,
    required this.portNets,
    required this.wireNets,
  });
}
