import 'dart:math' as math;

import 'geometry.dart';

/// Eixo que um caminho em "L" percorre primeiro.
enum RouteAxis { horizontal, vertical }

/// Alça de edição do traçado de um fio.
///
/// Sobre um vértice ([isSegment] falso) ela arrasta a curva ou a ponta; sobre
/// o meio de um trecho ([isSegment] verdadeiro) ela desliza o trecho, criando
/// uma curva nova.
class WireHandle {
  final GridPoint at;
  final int index;
  final bool isSegment;
  const WireHandle(this.at, {required this.index, required this.isSegment});
}

/// Fio: caminho ortogonal formado por um ou mais segmentos retos, tratado
/// como um único objeto pelo editor — é criado, selecionado, movido e apagado
/// de uma vez só, tenha ele curvas ou não.
///
/// Eletricamente o caminho inteiro é um único condutor: todos os seus pontos
/// pertencem à mesma rede.
class Wire {
  final int id;

  /// Vértices do caminho (pelo menos 2). Cada par consecutivo forma um
  /// segmento horizontal ou vertical.
  final List<GridPoint> points;

  Wire(this.id, List<GridPoint> points)
      : points = List.unmodifiable(normalizePath(points));

  /// Fio de um único segmento reto.
  factory Wire.segment(int id, GridPoint a, GridPoint b) => Wire(id, [a, b]);

  /// Fio em "L" entre dois pontos.
  factory Wire.route(int id, GridPoint from, GridPoint to,
          {RouteAxis? firstAxis}) =>
      Wire(id, routePath(from, to, firstAxis: firstAxis));

  /// Caminho em "L" usado pelo editor ao arrastar um fio.
  ///
  /// [firstAxis] diz por qual eixo o caminho começa — no editor é a direção do
  /// primeiro movimento do dedo, o que dá dois traçados diferentes para o mesmo
  /// par de pontos. Sem ela, vale o eixo dominante (o comportamento de sempre,
  /// usado pela importação e pelos testes).
  static List<GridPoint> routePath(
    GridPoint from,
    GridPoint to, {
    RouteAxis? firstAxis,
  }) {
    if (from.x == to.x || from.y == to.y) return [from, to];
    final dx = (to.x - from.x).abs();
    final dy = (to.y - from.y).abs();
    final horizontalFirst = switch (firstAxis) {
      RouteAxis.horizontal => true,
      RouteAxis.vertical => false,
      null => dx >= dy,
    };
    final corner =
        horizontalFirst ? GridPoint(to.x, from.y) : GridPoint(from.x, to.y);
    return [from, corner, to];
  }

  /// Limpa um caminho bruto: descarta pontos repetidos e trechos diagonais, e
  /// funde segmentos colineares consecutivos que seguem na mesma direção.
  static List<GridPoint> normalizePath(List<GridPoint> raw) {
    final ortho = <GridPoint>[];
    for (final p in raw) {
      if (ortho.isEmpty) {
        ortho.add(p);
        continue;
      }
      final last = ortho.last;
      if (p == last) continue;
      if (p.x != last.x && p.y != last.y) continue; // ignora diagonais
      ortho.add(p);
    }

    final merged = <GridPoint>[];
    for (final p in ortho) {
      if (merged.length >= 2) {
        final a = merged[merged.length - 2];
        final b = merged.last;
        final continuesRow =
            a.y == b.y && b.y == p.y && _sameSign(b.x - a.x, p.x - b.x);
        final continuesCol =
            a.x == b.x && b.x == p.x && _sameSign(b.y - a.y, p.y - b.y);
        if (continuesRow || continuesCol) {
          merged[merged.length - 1] = p;
          continue;
        }
      }
      merged.add(p);
    }
    return merged;
  }

  static bool _sameSign(int a, int b) => (a > 0 && b > 0) || (a < 0 && b < 0);

  GridPoint get start => points.first;
  GridPoint get end => points.last;

  /// As duas pontas do fio — os únicos pontos que criam conexão com outros
  /// fios (ver [Circuit.buildNetlist]).
  List<GridPoint> get endpoints => [start, end];

  bool get isDegenerate => points.length < 2;

  bool get hasCorners => points.length > 2;

  int get segmentCount => math.max(0, points.length - 1);

  /// Segmentos retos que compõem o caminho.
  Iterable<(GridPoint, GridPoint)> get segments sync* {
    for (var i = 0; i + 1 < points.length; i++) {
      yield (points[i], points[i + 1]);
    }
  }

  int get length {
    var total = 0;
    for (final (a, b) in segments) {
      total += (b.x - a.x).abs() + (b.y - a.y).abs();
    }
    return total;
  }

  /// O ponto [p] está sobre o caminho (em qualquer segmento, extremidades
  /// incluídas)?
  bool contains(GridPoint p) => distanceTo(p) == 0;

  /// O ponto [p] está sobre o caminho mas não é uma das duas pontas?
  bool containsInterior(GridPoint p) => p != start && p != end && contains(p);

  /// Distância do ponto ao segmento [index].
  int _distanceToSegment(int index, GridPoint p) {
    final a = points[index], b = points[index + 1];
    final minX = math.min(a.x, b.x), maxX = math.max(a.x, b.x);
    final minY = math.min(a.y, b.y), maxY = math.max(a.y, b.y);
    final dx = p.x < minX ? minX - p.x : (p.x > maxX ? p.x - maxX : 0);
    final dy = p.y < minY ? minY - p.y : (p.y > maxY ? p.y - maxY : 0);
    return dx + dy;
  }

  /// Distância (em unidades do mundo) do ponto ao caminho — usada para acertar
  /// o fio com o dedo, já que o toque raramente cai exatamente sobre a linha.
  int distanceTo(GridPoint p) {
    var best = 1 << 30;
    for (var i = 0; i + 1 < points.length; i++) {
      final d = _distanceToSegment(i, p);
      if (d < best) best = d;
    }
    return best;
  }

  /// Índice do trecho mais próximo de [p], ou null se nenhum estiver dentro de
  /// [tolerance].
  int? segmentIndexAt(GridPoint p, {int tolerance = 0}) {
    int? best;
    var bestDist = 1 << 30;
    for (var i = 0; i + 1 < points.length; i++) {
      final d = _distanceToSegment(i, p);
      if (d <= tolerance && d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  // ------------------------------------------------------ Edição do traçado

  /// Alças de edição: um vértice por ponto do caminho e um ponto médio por
  /// trecho.
  List<WireHandle> get handles {
    final result = <WireHandle>[];
    for (var i = 0; i < points.length; i++) {
      result.add(WireHandle(points[i], index: i, isSegment: false));
    }
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i], b = points[i + 1];
      result.add(WireHandle(
        GridPoint((a.x + b.x) ~/ 2, (a.y + b.y) ~/ 2),
        index: i,
        isSegment: true,
      ));
    }
    return result;
  }

  /// Move o vértice [index] para [to], mantendo o caminho ortogonal.
  ///
  /// O vértice para exatamente onde o dedo mandou, e os trechos vizinhos
  /// acompanham: o horizontal sobe ou desce até `to.y`, o vertical anda até
  /// `to.x`. Quando um vizinho é uma **ponta** do fio, ela não pode andar de
  /// tabela — um trecho de ligação é inserido para devolvê-la ao lugar, e a
  /// conexão elétrica fica intacta.
  ///
  /// Arrastar a própria ponta ([index] 0 ou o último) move ela de verdade: é
  /// assim que se muda onde o fio chega.
  Wire moveVertex(int index, GridPoint to) {
    if (index < 0 || index >= points.length) return this;
    if (points[index] == to) return this;
    final n = points.length;
    final pts = points.toList();

    for (final j in [index - 1, index + 1]) {
      if (j < 0 || j >= n) continue;
      final horizontal = points[j].y == points[index].y;
      pts[j] = horizontal
          ? GridPoint(points[j].x, to.y)
          : GridPoint(to.x, points[j].y);
    }
    pts[index] = to;

    // Pontas ajustadas só por serem vizinhas voltam para o lugar.
    if (index != n - 1 && index + 1 == n - 1) pts.add(points.last);
    if (index != 0 && index - 1 == 0) pts.insert(0, points.first);

    return Wire(id, pts);
  }

  /// Devolve o fio com as pontas levadas para os pontos dados (null = a ponta
  /// fica onde está), preservando o formato do meio do caminho.
  ///
  /// É o que faz o fio acompanhar um componente que mudou de lugar: só a perna
  /// que chega na porta se adapta.
  Wire withEndpoints({GridPoint? start, GridPoint? end}) {
    var w = this;
    if (start != null) w = w.moveVertex(0, start);
    // O último índice é recalculado: moveVertex pode ter inserido um ponto.
    if (end != null) w = w.moveVertex(w.points.length - 1, end);
    return w;
  }

  /// Desliza o trecho [index] até [to], perpendicularmente a ele mesmo.
  ///
  /// É o que cria curva nova: num fio reto o arraste insere ligações nas duas
  /// pontas e o caminho vira um "Z". Empurrar a curva de volta para a linha dos
  /// vizinhos faz [normalizePath] fundi-los e ela some sozinha.
  ///
  /// As duas pontas do fio nunca saem do lugar.
  Wire slideSegment(int index, GridPoint to) {
    if (index < 0 || index + 1 >= points.length) return this;
    final a = points[index], b = points[index + 1];
    final horizontal = a.y == b.y;
    final v = horizontal ? to.y : to.x;
    if (v == (horizontal ? a.y : a.x)) return this;

    GridPoint moved(GridPoint p) =>
        horizontal ? GridPoint(p.x, v) : GridPoint(v, p.y);

    final atStart = index == 0;
    final atEnd = index + 1 == points.length - 1;
    final pts = points.toList();
    pts[index] = moved(a);
    pts[index + 1] = moved(b);
    if (atEnd) pts.add(b);
    if (atStart) pts.insert(0, a);

    return Wire(id, pts);
  }

  Wire translated(int dx, int dy) =>
      Wire(id, [for (final p in points) p.translate(dx, dy)]);

  Wire withId(int newId) => Wire(newId, points);

  /// Mesmo traçado que [other] (em qualquer sentido), ignorando o id.
  bool samePath(Wire other) {
    if (other.points.length != points.length) return false;
    var forward = true, backward = true;
    final n = points.length;
    for (var i = 0; i < n; i++) {
      if (points[i] != other.points[i]) forward = false;
      if (points[i] != other.points[n - 1 - i]) backward = false;
    }
    return forward || backward;
  }

  @override
  bool operator ==(Object other) =>
      other is Wire && other.id == id && other.samePath(this);

  @override
  int get hashCode => Object.hash(id, points.length, start, end);

  @override
  String toString() =>
      'Wire#$id(${points.map((p) => '$p').join(' -> ')})';
}
