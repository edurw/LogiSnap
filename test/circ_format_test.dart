import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logisnap/core/circ_format.dart';
import 'package:logisnap/core/component.dart';
import 'package:logisnap/core/geometry.dart';
import 'package:logisnap/core/serialization.dart';

void main() {
  test('importa a meia-somadora com componentes e fios corretos', () {
    final xml =
        File('assets/examples/meia_somadora.circ').readAsStringSync();
    final result = CircFormat.import(xml);
    final c = result.circuit;
    expect(result.warnings, isEmpty);
    expect(c.components.length, 6);
    // O arquivo tem 10 <wire>; os segmentos encadeados são remontados em
    // caminhos únicos na importação (ver Circuit.mergeWirePaths).
    expect(c.wires.length, 6);
    expect(
      c.components.where((e) => e.type == ComponentType.inputPin).length,
      2,
    );
    expect(
      c.components.where((e) => e.type == ComponentType.outputPin).length,
      2,
    );
    final xor =
        c.components.firstWhere((e) => e.type == ComponentType.xorGate);
    expect(xor.inputs, 2);
    expect(xor.location, const GridPoint(330, 190));
    // Geometria do Logisim: XOR médio tem entradas 60 atrás da saída.
    expect(xor.ports[1].location, const GridPoint(270, 180));
  });

  test('componentes sem suporte saem da contagem, não do resto', () {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<project source="3.8.0" version="1.0">
  <lib desc="#Wiring" name="0"/>
  <lib desc="#Memory" name="4"/>
  <main name="main"/>
  <circuit name="main">
    <comp lib="0" loc="(100,100)" name="Pin"/>
    <comp lib="4" loc="(200,100)" name="D Flip-Flop"/>
    <comp loc="(300,100)" name="subcircuito"/>
  </circuit>
</project>
''';
    final result = CircFormat.import(xml);
    expect(result.circuit.components.length, 1);
    expect(result.omitted, {
      'Flip-flop D': 1,
      'Subcircuito "subcircuito"': 1,
    });
  });

  test('pino de 8 bits importa com aviso de largura', () {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<project source="3.8.0" version="1.0">
  <lib desc="#Wiring" name="0"/>
  <main name="main"/>
  <circuit name="main">
    <comp lib="0" loc="(100,100)" name="Pin">
      <a name="width" val="8"/>
    </comp>
  </circuit>
</project>
''';
    final result = CircFormat.import(xml);
    expect(result.circuit.components.length, 1);
    expect(result.warnings, hasLength(1));
    expect(result.warnings.single, contains('8 bits'));
  });

  test('exportar e reimportar preserva o circuito', () {
    final xml = File('assets/examples/latch_sr.circ').readAsStringSync();
    final original = CircFormat.import(xml).circuit;
    final exported = CircFormat.export(original);
    final reimported = CircFormat.import(exported).circuit;

    expect(reimported.components.length, original.components.length);
    expect(reimported.wires.length, original.wires.length);
    for (var i = 0; i < original.components.length; i++) {
      final a = original.components[i];
      final b = reimported.components
          .firstWhere((e) => e.x == a.x && e.y == a.y && e.type == a.type);
      expect(b.label, a.label);
      expect(b.facing, a.facing);
      if (a.type.isMultiInputGate) expect(b.inputs, a.inputs);
    }
  });

  test('JSON: salvar e reabrir preserva o circuito', () {
    final xml =
        File('assets/examples/meia_somadora.circ').readAsStringSync();
    final original = CircFormat.import(xml).circuit;
    final encoded = CircuitJson.encode(original);
    final decoded = CircuitJson.decode(encoded);
    expect(decoded.components.length, original.components.length);
    expect(decoded.wires.length, original.wires.length);
    expect(decoded.name, original.name);
  });

  test('componentes sem suporte ficam de fora, contados por nome', () {
    // Dois flip-flops D, uma RAM e um subcircuito, misturados com coisas que
    // o app entende; os fios ligam tudo.
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<project source="3.8.0" version="1.0">
  <lib desc="#Wiring" name="0"/>
  <lib desc="#Gates" name="1"/>
  <lib desc="#Memory" name="4"/>
  <main name="main"/>
  <circuit name="main">
    <comp lib="0" loc="(100,100)" name="Pin"/>
    <comp lib="0" loc="(400,100)" name="Pin">
      <a name="output" val="true"/>
    </comp>
    <comp lib="1" loc="(250,100)" name="AND Gate">
      <a name="inputs" val="2"/>
    </comp>
    <comp lib="4" loc="(300,300)" name="D Flip-Flop"/>
    <comp lib="4" loc="(300,400)" name="D Flip-Flop"/>
    <comp lib="4" loc="(300,500)" name="RAM"/>
    <comp loc="(300,600)" name="somador4"/>
    <wire from="(100,100)" to="(200,100)"/>
    <wire from="(250,100)" to="(400,100)"/>
    <wire from="(100,100)" to="(100,300)"/>
    <wire from="(100,300)" to="(300,300)"/>
  </circuit>
</project>
''';
    final result = CircFormat.import(xml);
    final c = result.circuit;

    // O que o app entende entrou normalmente.
    expect(c.components, hasLength(3));
    expect(c.components.where((e) => e.type == ComponentType.andGate),
        hasLength(1));
    expect(c.components.where((e) => e.type == ComponentType.inputPin),
        hasLength(1));
    expect(c.components.where((e) => e.type == ComponentType.outputPin),
        hasLength(1));

    // O que faltava está contado por nome em português.
    expect(result.omitted, {
      'Flip-flop D': 2,
      'Memória RAM': 1,
      'Subcircuito "somador4"': 1,
    });
    expect(result.omittedLabels, contains('Flip-flop D (2)'));

    // Os fios continuam todos lá, inclusive o que ia para o flip-flop. São
    // três porque os dois segmentos até (300,300) viram um caminho só.
    expect(c.wires, hasLength(3));
    final solto = c.wires.firstWhere((w) => w.contains(const GridPoint(300, 300)));
    // A ponta ficou em aberto: não há componente nenhum naquele ponto.
    expect(c.portAt(const GridPoint(300, 300), tolerance: 10), isNull);
    expect(solto.contains(const GridPoint(100, 100)), isTrue);

    // A omissão não vira aviso solto: o diálogo mostra a lista contada.
    expect(result.warnings, isEmpty);
  });
}
