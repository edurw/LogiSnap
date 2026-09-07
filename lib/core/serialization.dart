import 'dart:convert';

import 'circuit.dart';
import 'component.dart';
import 'geometry.dart';
import 'values.dart';

/// Salva/carrega circuitos no formato JSON próprio do app.
class CircuitJson {
  /// Versão 2: fios passaram a ser caminhos (`points`) em vez de segmentos
  /// retos (`x1,y1,x2,y2`). A leitura ainda aceita o formato antigo.
  static const int formatVersion = 2;

  static String encode(Circuit circuit) =>
      const JsonEncoder.withIndent('  ').convert(toMap(circuit));

  static Map<String, dynamic> toMap(Circuit circuit) => {
        'app': 'logisnap',
        'version': formatVersion,
        'name': circuit.name,
        'components': [
          for (final c in circuit.components)
            {
              'id': c.id,
              'type': c.type.name,
              'x': c.x,
              'y': c.y,
              'facing': c.facing.name,
              if (c.type.isMultiInputGate) 'inputs': c.inputs,
              if (c.type.isGate) 'size': c.size,
              if (c.label.isNotEmpty) 'label': c.label,
              if (c.type == ComponentType.constant)
                'value': c.state == LogicValue.one ? 1 : 0,
            }
        ],
        'wires': [
          for (final w in circuit.wires)
            {
              'id': w.id,
              'points': [
                for (final p in w.points) [p.x, p.y]
              ],
            }
        ],
      };

  static Circuit decode(String source) {
    final map = json.decode(source);
    if (map is! Map<String, dynamic>) {
      throw const FormatException('Arquivo de projeto inválido.');
    }
    return fromMap(map);
  }

  static Circuit fromMap(Map<String, dynamic> map) {
    final circuit = Circuit(name: (map['name'] as String?) ?? 'principal');
    final comps = (map['components'] as List?) ?? const [];
    for (final raw in comps) {
      final m = raw as Map<String, dynamic>;
      final type = ComponentType.values.firstWhere(
        (t) => t.name == m['type'],
        orElse: () => throw FormatException(
            'Componente desconhecido: ${m['type']}'),
      );
      final c = Component(
        id: (m['id'] as num).toInt(),
        type: type,
        x: (m['x'] as num).toInt(),
        y: (m['y'] as num).toInt(),
        facing: Facing.parse(m['facing'] as String?),
        inputs: (m['inputs'] as num?)?.toInt(),
        size: (m['size'] as num?)?.toInt(),
        label: (m['label'] as String?) ?? '',
        state: type == ComponentType.constant
            ? ((m['value'] as num?)?.toInt() == 0
                ? LogicValue.zero
                : LogicValue.one)
            : LogicValue.zero,
      );
      circuit.addComponent(c);
    }
    final wires = (map['wires'] as List?) ?? const [];
    for (final raw in wires) {
      final m = raw as Map<String, dynamic>;
      final rawPoints = m['points'] as List?;
      if (rawPoints != null) {
        circuit.addWirePath(
          [
            for (final e in rawPoints)
              GridPoint(
                ((e as List)[0] as num).toInt(),
                (e[1] as num).toInt(),
              )
          ],
          id: (m['id'] as num?)?.toInt(),
        );
      } else {
        // Formato 1: um fio por segmento reto.
        circuit.addWire(
          GridPoint((m['x1'] as num).toInt(), (m['y1'] as num).toInt()),
          GridPoint((m['x2'] as num).toInt(), (m['y2'] as num).toInt()),
        );
      }
    }
    return circuit;
  }
}
