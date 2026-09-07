import 'geometry.dart';
import 'values.dart';

/// Tipos de componente suportados no MVP.
enum ComponentType {
  inputPin,
  outputPin,
  led,
  button,
  clock,
  constant,
  notGate,
  bufferGate,
  andGate,
  orGate,
  nandGate,
  norGate,
  xorGate,
  xnorGate;

  bool get isGate => index >= ComponentType.notGate.index;

  bool get isMultiInputGate =>
      isGate && this != ComponentType.notGate && this != ComponentType.bufferGate;

  String get displayName {
    switch (this) {
      case ComponentType.inputPin:
        return 'Entrada';
      case ComponentType.outputPin:
        return 'Saída';
      case ComponentType.led:
        return 'LED';
      case ComponentType.button:
        return 'Botão';
      case ComponentType.clock:
        return 'Clock';
      case ComponentType.constant:
        return 'Constante';
      case ComponentType.notGate:
        return 'NOT';
      case ComponentType.bufferGate:
        return 'Buffer';
      case ComponentType.andGate:
        return 'AND';
      case ComponentType.orGate:
        return 'OR';
      case ComponentType.nandGate:
        return 'NAND';
      case ComponentType.norGate:
        return 'NOR';
      case ComponentType.xorGate:
        return 'XOR';
      case ComponentType.xnorGate:
        return 'XNOR';
    }
  }
}

/// Porta (ponto de conexão) de um componente, em coordenadas absolutas.
class Port {
  final GridPoint location;
  final bool isOutput;
  final int index;
  const Port(this.location, {required this.isOutput, required this.index});
}

/// Um componente posicionado no circuito.
///
/// Como no Logisim, [x]/[y] são a âncora do componente: para portas lógicas é
/// o ponto da saída; para pinos, LED, botão, clock e constante é o próprio
/// ponto de conexão.
class Component {
  final int id;
  ComponentType type;
  int x;
  int y;
  Facing facing;

  /// Número de entradas (apenas portas de múltiplas entradas). Padrão 2.
  int inputs;

  /// Tamanho no estilo Logisim (30 = estreito, 50 = médio, 70 = largo).
  int size;

  String label;

  /// Estado interno interativo (pino de entrada, botão, clock, constante).
  LogicValue state;

  Component({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.facing = Facing.east,
    int? inputs,
    int? size,
    this.label = '',
    LogicValue? state,
  })  : inputs = inputs ?? (type.isMultiInputGate ? 2 : 0),
        size = size ?? _defaultSize(type),
        state = state ??
            (type == ComponentType.constant ? LogicValue.one : LogicValue.zero);

  static int _defaultSize(ComponentType type) {
    switch (type) {
      case ComponentType.notGate:
        return 30;
      case ComponentType.bufferGate:
        return 20;
      default:
        return 50;
    }
  }

  GridPoint get location => GridPoint(x, y);

  /// Comprimento do corpo no eixo da saída → entradas (geometria do Logisim,
  /// para que arquivos .circ liguem os fios nos pontos certos).
  int get axisLength {
    switch (type) {
      case ComponentType.notGate:
        return size; // triângulo + bolha já inclusos (padrão 30)
      case ComponentType.bufferGate:
        return 20;
      case ComponentType.andGate:
      case ComponentType.orGate:
        return size;
      case ComponentType.nandGate:
      case ComponentType.norGate:
        return size + 10; // bolha de negação
      case ComponentType.xorGate:
        return size + 10; // arco extra atrás
      case ComponentType.xnorGate:
        return size + 20; // arco extra + bolha
      default:
        return 0;
    }
  }

  /// Meia-altura do corpo desenhado, perpendicular ao eixo saída→entradas.
  ///
  /// É a mesma medida usada para desenhar a porta, para que a área de toque e
  /// o retângulo de seleção fiquem colados no componente.
  int get bodyHalfHeight {
    // NOT e Buffer são triângulos de altura fixa; os demais acompanham a
    // distribuição das entradas.
    if (!type.isMultiInputGate) return 10;
    final offsets = inputOffsets(inputs);
    return ((offsets.last - offsets.first) ~/ 2 + 10).clamp(15, 200);
  }

  /// Quanto o corpo se estende atrás da âncora, no eixo do componente.
  int get bodyDepth => type.isGate ? axisLength : 20;

  /// Deslocamentos perpendiculares das entradas (espaçados de 10, pulando o
  /// centro quando o número de entradas é par — regra do Logisim).
  static List<int> inputOffsets(int n) {
    if (n == 1) return const [0];
    final result = <int>[];
    final half = n ~/ 2;
    for (var i = 0; i < n; i++) {
      var dy = (i - half) * 10;
      if (n.isEven && dy >= 0) dy += 10;
      result.add(dy);
    }
    return result;
  }

  /// Todas as portas do componente em coordenadas absolutas.
  List<Port> get ports {
    switch (type) {
      case ComponentType.inputPin:
      case ComponentType.button:
      case ComponentType.clock:
      case ComponentType.constant:
        return [Port(location, isOutput: true, index: 0)];
      case ComponentType.outputPin:
      case ComponentType.led:
        return [Port(location, isOutput: false, index: 0)];
      case ComponentType.notGate:
      case ComponentType.bufferGate:
        final d = facing.rotate(-axisLength, 0);
        return [
          Port(location, isOutput: true, index: 0),
          Port(location.translate(d.x, d.y), isOutput: false, index: 1),
        ];
      default:
        final result = <Port>[Port(location, isOutput: true, index: 0)];
        final offsets = inputOffsets(inputs);
        for (var i = 0; i < offsets.length; i++) {
          final d = facing.rotate(-axisLength, offsets[i]);
          result.add(
            Port(location.translate(d.x, d.y), isOutput: false, index: i + 1),
          );
        }
        return result;
    }
  }

  /// Calcula a saída da porta lógica a partir dos valores das entradas.
  ///
  /// Entradas flutuantes ([LogicValue.unknown]) são ignoradas nas portas de
  /// múltiplas entradas, como no Logisim; se todas estiverem flutuantes, ou se
  /// alguma entrada usada estiver em erro, a saída é erro.
  LogicValue computeGate(List<LogicValue> ins) {
    switch (type) {
      case ComponentType.notGate:
        return ins[0].not;
      case ComponentType.bufferGate:
        return ins[0].isDefined ? ins[0] : LogicValue.error;
      default:
        final used = ins.where((v) => v != LogicValue.unknown).toList();
        if (used.isEmpty) return LogicValue.error;
        if (used.any((v) => v == LogicValue.error)) return LogicValue.error;
        bool acc;
        switch (type) {
          case ComponentType.andGate:
          case ComponentType.nandGate:
            acc = used.every((v) => v == LogicValue.one);
            break;
          case ComponentType.orGate:
          case ComponentType.norGate:
            acc = used.any((v) => v == LogicValue.one);
            break;
          case ComponentType.xorGate:
          case ComponentType.xnorGate:
            acc = used.where((v) => v == LogicValue.one).length.isOdd;
            break;
          default:
            return LogicValue.error;
        }
        final negated = type == ComponentType.nandGate ||
            type == ComponentType.norGate ||
            type == ComponentType.xnorGate;
        if (negated) acc = !acc;
        return acc ? LogicValue.one : LogicValue.zero;
    }
  }

  Component copy({int? id}) => Component(
        id: id ?? this.id,
        type: type,
        x: x,
        y: y,
        facing: facing,
        inputs: type.isMultiInputGate ? inputs : null,
        size: size,
        label: label,
        state: state,
      );
}
