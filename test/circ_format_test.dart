import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logisim_mobile/core/circ_format.dart';
import 'package:logisim_mobile/core/component.dart';
import 'package:logisim_mobile/core/geometry.dart';
import 'package:logisim_mobile/core/serialization.dart';

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

  test('componentes sem suporte geram aviso e são ignorados', () {
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
    expect(result.warnings.length, 2);
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
}
