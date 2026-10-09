import 'package:xml/xml.dart';

import 'circuit.dart';
import 'component.dart';
import 'geometry.dart';
import 'values.dart';

/// Resultado de uma importação de arquivo .circ, com avisos sobre o que não
/// pôde ser convertido.
class CircImportResult {
  final Circuit circuit;
  final List<String> warnings;

  /// Componentes que este app ainda não tem, contados por nome em português
  /// (ex.: `{'Flip-flop D': 2}`). O resto do circuito entra normalmente e os
  /// fios que chegavam neles ficam com as pontas em aberto.
  final Map<String, int> omitted;

  CircImportResult(this.circuit, this.warnings, {this.omitted = const {}});

  /// Rótulos prontos para mostrar na tela: `Flip-flop D (2)`.
  List<String> get omittedLabels =>
      [for (final e in omitted.entries) '${e.key} (${e.value})'];
}

/// Importa e exporta arquivos `.circ` do Logisim / Logisim Evolution.
///
/// A geometria dos componentes deste app segue a do Logisim (mesma grade,
/// mesmos pontos de conexão), então componentes e fios são convertidos
/// diretamente, preservando o layout.
class CircFormat {
  static const _gateNames = {
    'AND Gate': ComponentType.andGate,
    'OR Gate': ComponentType.orGate,
    'NOT Gate': ComponentType.notGate,
    'NAND Gate': ComponentType.nandGate,
    'NOR Gate': ComponentType.norGate,
    'XOR Gate': ComponentType.xorGate,
    'XNOR Gate': ComponentType.xnorGate,
    'Buffer': ComponentType.bufferGate,
  };

  static const _wiringNames = {
    'Clock': ComponentType.clock,
    'Constant': ComponentType.constant,
  };

  static const _ioNames = {
    'LED': ComponentType.led,
    'Button': ComponentType.button,
  };


  /// Nome em português dos componentes do Logisim que este app ainda não
  /// tem. O que não estiver aqui aparece com o nome original do arquivo.
  static const _nomesNaoSuportados = {
    // #Memory
    'D Flip-Flop': 'Flip-flop D',
    'T Flip-Flop': 'Flip-flop T',
    'J-K Flip-Flop': 'Flip-flop JK',
    'S-R Flip-Flop': 'Flip-flop SR',
    'Register': 'Registrador',
    'Counter': 'Contador',
    'Shift Register': 'Registrador de deslocamento',
    'Random': 'Gerador aleatório',
    'RAM': 'Memória RAM',
    'ROM': 'Memória ROM',
    // #Plexers
    'Multiplexer': 'Multiplexador',
    'Demultiplexer': 'Demultiplexador',
    'Decoder': 'Decodificador',
    'Priority Encoder': 'Codificador de prioridade',
    'BitSelector': 'Seletor de bits',
    // #Arithmetic
    'Adder': 'Somador',
    'Subtractor': 'Subtrator',
    'Multiplier': 'Multiplicador',
    'Divider': 'Divisor',
    'Negator': 'Negador',
    'Comparator': 'Comparador',
    'Shifter': 'Deslocador',
    'BitAdder': 'Somador de bits',
    'BitFinder': 'Localizador de bits',
    // #Wiring
    'Splitter': 'Divisor de barramento',
    'Tunnel': 'Túnel',
    'Pull Resistor': 'Resistor de pull',
    'Power': 'Alimentação',
    'Ground': 'Terra',
    'Transistor': 'Transistor',
    'Transmission Gate': 'Porta de transmissão',
    'Bit Extender': 'Extensor de bits',
    'Probe': 'Sonda',
    // #Gates
    'Controlled Buffer': 'Buffer controlado',
    'Controlled Inverter': 'Inversor controlado',
    'Even Parity': 'Paridade par',
    'Odd Parity': 'Paridade ímpar',
    // #I/O
    '7-Segment Display': 'Display de 7 segmentos',
    'Hex Digit Display': 'Display hexadecimal',
    'LED Matrix': 'Matriz de LEDs',
    'Keyboard': 'Teclado',
    'Joystick': 'Joystick',
    'TTY': 'Terminal',
  };

  static void _contar(Map<String, int> contagem, String nome) =>
      contagem[nome] = (contagem[nome] ?? 0) + 1;

  // ---------------------------------------------------------------- Import

  static CircImportResult import(String xmlSource, {String? circuitName}) {
    final warnings = <String>[];
    // Componentes que o app ainda não tem, contados por nome para o aviso
    // do fim da importação.
    final omitidos = <String, int>{};
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlSource);
    } on XmlException catch (e) {
      throw FormatException('XML inválido: ${e.message}');
    }

    final project = doc.getElement('project');
    if (project == null) {
      throw const FormatException(
          'Arquivo .circ inválido: elemento <project> não encontrado.');
    }

    // Bibliotecas: nome ("0", "1", ...) -> descrição ("#Wiring", "#Gates"...).
    final libs = <String, String>{};
    for (final lib in project.findElements('lib')) {
      final name = lib.getAttribute('name');
      final desc = lib.getAttribute('desc');
      if (name != null && desc != null) libs[name] = desc;
    }

    final circuits = project.findElements('circuit').toList();
    if (circuits.isEmpty) {
      throw const FormatException('O arquivo não contém nenhum circuito.');
    }
    final mainName =
        circuitName ?? project.getElement('main')?.getAttribute('name');
    final circuitEl = circuits.firstWhere(
      (c) => c.getAttribute('name') == mainName,
      orElse: () => circuits.first,
    );
    if (circuits.length > 1) {
      warnings.add(
          'O arquivo tem ${circuits.length} circuitos; foi importado apenas '
          '"${circuitEl.getAttribute('name')}" (subcircuitos não são '
          'suportados nesta versão).');
    }

    final circuit =
        Circuit(name: circuitEl.getAttribute('name') ?? 'importado');

    for (final comp in circuitEl.findElements('comp')) {
      final compName = comp.getAttribute('name') ?? '?';
      final libId = comp.getAttribute('lib');
      final loc = _parseLoc(comp.getAttribute('loc'));
      if (loc == null) {
        warnings.add('Componente "$compName" sem posição válida foi ignorado.');
        continue;
      }
      if (libId == null) {
        // Subcircuito: o arquivo guarda o desenho dele à parte, e esta
        // versão ainda não monta subcircuitos.
        _contar(omitidos, 'Subcircuito "$compName"');
        continue;
      }
      final libDesc = libs[libId] ?? '';
      final attrs = <String, String>{};
      for (final a in comp.findElements('a')) {
        final n = a.getAttribute('name');
        final v = a.getAttribute('val');
        if (n != null && v != null) attrs[n] = v;
      }

      final type = _typeFor(libDesc, compName, attrs);
      if (type == null) {
        // Componente que o app ainda não tem: fica de fora, e os fios que
        // chegavam nele continuam no circuito com as pontas em aberto.
        _contar(omitidos, _nomesNaoSuportados[compName] ?? compName);
        continue;
      }

      final width = int.tryParse(attrs['width'] ?? '1') ?? 1;
      if (width != 1) {
        warnings.add(
            '"$compName" em $loc usa $width bits; esta versão simula apenas '
            '1 bit.');
      }

      final defaultFacing =
          type == ComponentType.led ? Facing.west : Facing.east;
      final inputsAttr = int.tryParse(attrs['inputs'] ?? '');
      final c = Component(
        id: circuit.newId(),
        type: type,
        x: loc.x,
        y: loc.y,
        facing: Facing.parse(attrs['facing'], defaultFacing),
        // No Logisim, portas sem o atributo "inputs" têm 5 entradas.
        inputs: type.isMultiInputGate ? (inputsAttr ?? 5) : null,
        size: int.tryParse(attrs['size'] ?? ''),
        label: attrs['label'] ?? '',
      );
      if (type == ComponentType.constant) {
        final v = (attrs['value'] ?? '0x1').replaceFirst('0x', '');
        c.state =
            (int.tryParse(v, radix: 16) ?? 1) == 0 ? LogicValue.zero : LogicValue.one;
      }
      if ((type == ComponentType.xorGate || type == ComponentType.xnorGate) &&
          c.inputs > 2) {
        warnings.add(
            'XOR/XNOR em $loc com ${c.inputs} entradas: simulado como paridade '
            'ímpar.');
      }
      circuit.addComponent(c);
    }

    for (final wire in circuitEl.findElements('wire')) {
      final from = _parseLoc(wire.getAttribute('from'));
      final to = _parseLoc(wire.getAttribute('to'));
      if (from == null || to == null) continue;
      circuit.addWire(from, to);
    }
    // O .circ guarda um <wire> por segmento reto. Remonta os segmentos
    // encadeados em caminhos únicos, para que cada fio seja um objeto só no
    // editor.
    circuit.mergeWirePaths();

    return CircImportResult(circuit, warnings, omitted: omitidos);
  }

  static ComponentType? _typeFor(
      String libDesc, String compName, Map<String, String> attrs) {
    if (libDesc == '#Gates') return _gateNames[compName];
    if (libDesc == '#Wiring' || libDesc == '#Base') {
      if (compName == 'Pin') {
        return attrs['output'] == 'true'
            ? ComponentType.outputPin
            : ComponentType.inputPin;
      }
      return _wiringNames[compName];
    }
    if (libDesc == '#I/O') return _ioNames[compName];
    return null;
  }

  static GridPoint? _parseLoc(String? s) {
    if (s == null) return null;
    final m = RegExp(r'\((-?\d+),\s*(-?\d+)\)').firstMatch(s);
    if (m == null) return null;
    return GridPoint(int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  // ---------------------------------------------------------------- Export

  static String export(Circuit circuit) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8" standalone="no"');
    b.element('project', attributes: {
      'source': '3.8.0',
      'version': '1.0'
    }, nest: () {
      b.element('lib', attributes: {'desc': '#Wiring', 'name': '0'});
      b.element('lib', attributes: {'desc': '#Gates', 'name': '1'});
      b.element('lib', attributes: {'desc': '#I/O', 'name': '5'});
      b.element('main', attributes: {'name': 'main'});
      b.element('options');
      b.element('mappings');
      b.element('toolbar');
      b.element('circuit', attributes: {'name': 'main'}, nest: () {
        b.element('a', attributes: {'name': 'circuit', 'val': 'main'});
        for (final c in circuit.components) {
          final info = _circInfoFor(c);
          if (info == null) continue;
          b.element('comp', attributes: {
            'lib': info.$1,
            'loc': '(${c.x},${c.y})',
            'name': info.$2,
          }, nest: () {
            for (final e in info.$3.entries) {
              b.element('a', attributes: {'name': e.key, 'val': e.value});
            }
          });
        }
        // O Logisim só conhece segmentos retos: um caminho com curvas sai
        // como vários <wire> encadeados.
        for (final w in circuit.wires) {
          for (final (from, to) in w.segments) {
            b.element('wire', attributes: {
              'from': '(${from.x},${from.y})',
              'to': '(${to.x},${to.y})',
            });
          }
        }
      });
    });
    return b.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  /// (lib, nome, atributos) de um componente no formato .circ.
  static (String, String, Map<String, String>)? _circInfoFor(Component c) {
    final attrs = <String, String>{};
    if (c.label.isNotEmpty) attrs['label'] = c.label;

    String facingAttr() => c.facing.circName;

    switch (c.type) {
      case ComponentType.inputPin:
      case ComponentType.outputPin:
        if (c.type == ComponentType.outputPin) attrs['output'] = 'true';
        if (c.facing != Facing.east) attrs['facing'] = facingAttr();
        return ('0', 'Pin', attrs);
      case ComponentType.clock:
        if (c.facing != Facing.east) attrs['facing'] = facingAttr();
        return ('0', 'Clock', attrs);
      case ComponentType.constant:
        attrs['value'] = c.state == LogicValue.one ? '0x1' : '0x0';
        if (c.facing != Facing.east) attrs['facing'] = facingAttr();
        return ('0', 'Constant', attrs);
      case ComponentType.led:
        if (c.facing != Facing.west) attrs['facing'] = facingAttr();
        return ('5', 'LED', attrs);
      case ComponentType.button:
        if (c.facing != Facing.east) attrs['facing'] = facingAttr();
        return ('5', 'Button', attrs);
      default:
        final name = _gateNames.entries
            .firstWhere((e) => e.value == c.type)
            .key;
        if (c.facing != Facing.east) attrs['facing'] = facingAttr();
        if (c.type.isMultiInputGate) {
          attrs['inputs'] = '${c.inputs}';
          attrs['size'] = '${c.size}';
        } else if (c.type == ComponentType.notGate) {
          attrs['size'] = '${c.size}';
        }
        return ('1', name, attrs);
    }
  }
}
