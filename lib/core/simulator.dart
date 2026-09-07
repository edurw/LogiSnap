import 'circuit.dart';
import 'component.dart';
import 'values.dart';
import 'wire.dart';

/// Motor de simulação: propaga sinais até estabilizar.
///
/// A cada mudança (toque em um pino, edição do circuito, tick do clock) a
/// simulação recalcula as redes iterativamente. Circuitos combinacionais e
/// sequenciais assíncronos (ex.: latch SR) convergem; realimentações
/// instáveis (ex.: anel de NOTs) são detectadas como oscilação.
class Simulator {
  final Circuit circuit;
  Netlist _netlist;
  List<LogicValue> _netValues = const [];
  bool oscillating = false;

  /// Saída atual de cada componente (id -> valor da porta de saída).
  final Map<int, LogicValue> _outputs = {};

  Simulator(this.circuit) : _netlist = circuit.buildNetlist() {
    propagate();
  }

  /// Deve ser chamado sempre que componentes/fios mudarem.
  void rebuild() {
    _netlist = circuit.buildNetlist();
    propagate();
  }

  Netlist get netlist => _netlist;

  LogicValue valueOfNet(int netId) =>
      (netId >= 0 && netId < _netValues.length)
          ? _netValues[netId]
          : LogicValue.unknown;

  LogicValue valueOfWire(Wire w) {
    final id = _netlist.wireNets[w.id];
    return id == null ? LogicValue.unknown : valueOfNet(id);
  }

  LogicValue valueOfPort(Component c, int portIndex) {
    final id = _netlist.portNets[(c.id, portIndex)];
    return id == null ? LogicValue.unknown : valueOfNet(id);
  }

  /// Valor "visto" por um componente de leitura (LED, pino de saída).
  LogicValue displayValueOf(Component c) => valueOfPort(c, 0);

  static const int _maxIterations = 400;

  void propagate() {
    oscillating = false;
    final nets = List<LogicValue>.filled(_netlist.netCount, LogicValue.unknown);

    // Saídas independentes de entradas (fontes).
    for (final c in circuit.components) {
      switch (c.type) {
        case ComponentType.inputPin:
        case ComponentType.button:
        case ComponentType.clock:
        case ComponentType.constant:
          _outputs[c.id] = c.state;
          break;
        default:
          _outputs.putIfAbsent(c.id, () => LogicValue.unknown);
      }
    }

    var changed = true;
    var iterations = 0;
    while (changed && iterations < _maxIterations) {
      iterations++;
      changed = false;

      // 1. Resolve os valores das redes a partir das saídas atuais.
      final next = List<LogicValue>.filled(nets.length, LogicValue.unknown);
      for (final c in circuit.components) {
        final out = _outputPortOf(c);
        if (out == null) continue;
        final netId = _netlist.portNets[(c.id, 0)];
        if (netId == null) continue;
        next[netId] = LogicValue.resolve(next[netId], out);
      }
      for (var i = 0; i < nets.length; i++) {
        if (nets[i] != next[i]) {
          nets[i] = next[i];
          changed = true;
        }
      }

      // 2. Recalcula as portas lógicas a partir das redes.
      for (final c in circuit.components) {
        if (!c.type.isGate) continue;
        final ins = <LogicValue>[];
        for (final p in c.ports) {
          if (p.isOutput) continue;
          final netId = _netlist.portNets[(c.id, p.index)];
          ins.add(netId == null ? LogicValue.unknown : nets[netId]);
        }
        final out = c.computeGate(ins);
        if (_outputs[c.id] != out) {
          _outputs[c.id] = out;
          changed = true;
        }
      }
    }

    if (changed) oscillating = true;
    _netValues = nets;
  }

  LogicValue? _outputPortOf(Component c) {
    switch (c.type) {
      case ComponentType.outputPin:
      case ComponentType.led:
        return null;
      default:
        return _outputs[c.id];
    }
  }

  bool get hasClock =>
      circuit.components.any((c) => c.type == ComponentType.clock);

  /// Alterna todos os clocks e propaga (meio ciclo).
  void tickClocks() {
    for (final c in circuit.components) {
      if (c.type == ComponentType.clock) {
        c.state = c.state == LogicValue.one ? LogicValue.zero : LogicValue.one;
      }
    }
    propagate();
  }
}
