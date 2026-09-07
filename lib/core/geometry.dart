import 'dart:math' as math;

/// Tamanho da célula da grade (mesma unidade do Logisim).
const int kGrid = 10;

int snap(double v) => (v / kGrid).round() * kGrid;

/// Ponto em coordenadas de grade (sempre múltiplos de [kGrid]).
class GridPoint {
  final int x;
  final int y;
  const GridPoint(this.x, this.y);

  GridPoint translate(int dx, int dy) => GridPoint(x + dx, y + dy);

  @override
  bool operator ==(Object other) =>
      other is GridPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}

/// Direção para onde o componente "aponta" (lado da saída, como no Logisim).
enum Facing {
  east,
  west,
  north,
  south;

  /// Rotaciona um deslocamento definido com o componente virado para leste.
  ///
  /// Segue a convenção do Logisim (`Location.rotate`), com o eixo Y
  /// crescendo para baixo.
  GridPoint rotate(int dx, int dy) {
    switch (this) {
      case Facing.east:
        return GridPoint(dx, dy);
      case Facing.west:
        return GridPoint(-dx, -dy);
      case Facing.north:
        return GridPoint(dy, -dx);
      case Facing.south:
        return GridPoint(-dy, dx);
    }
  }

  /// Ângulo (rad) para desenhar o componente; leste = 0.
  double get angle {
    switch (this) {
      case Facing.east:
        return 0;
      case Facing.west:
        return math.pi;
      case Facing.north:
        return -math.pi / 2;
      case Facing.south:
        return math.pi / 2;
    }
  }

  Facing get rotatedClockwise {
    switch (this) {
      case Facing.east:
        return Facing.south;
      case Facing.south:
        return Facing.west;
      case Facing.west:
        return Facing.north;
      case Facing.north:
        return Facing.east;
    }
  }

  static Facing parse(String? s, [Facing fallback = Facing.east]) {
    switch (s) {
      case 'east':
        return Facing.east;
      case 'west':
        return Facing.west;
      case 'north':
        return Facing.north;
      case 'south':
        return Facing.south;
    }
    return fallback;
  }

  String get circName => name;
}
