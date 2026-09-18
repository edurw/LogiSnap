// O toque marca o meio do componente, não a âncora dele (que fica na saída
// das portas e no ponto de conexão dos pinos, sempre numa borda).

import 'package:flutter_test/flutter_test.dart';
import 'package:logisnap/core/component.dart';
import 'package:logisnap/core/geometry.dart';
import 'package:logisnap/state/editor_state.dart';

void main() {
  test('todo componente nasce centrado no toque e na grade', () {
    const alvo = GridPoint(100, 100);

    for (final tipo in ComponentType.values) {
      final st = EditorState();
      addTearDown(st.dispose);
      st.choosePaletteType(tipo);
      st.placeAt(alvo);

      final c = st.circuit.components.single;
      final b = st.circuit.boundsOf(c);
      final meioX = (b[0] + b[2]) / 2;
      final meioY = (b[1] + b[3]) / 2;

      // Meia casa da grade é o máximo que o reencaixe pode deslocar.
      expect((meioX - alvo.x).abs(), lessThanOrEqualTo(kGrid / 2),
          reason: '${tipo.displayName} ficou descentrado em x');
      expect((meioY - alvo.y).abs(), lessThanOrEqualTo(kGrid / 2),
          reason: '${tipo.displayName} ficou descentrado em y');

      // A âncora precisa continuar na grade, senão as portas saem do
      // alinhamento e os fios não encaixam.
      expect(c.x % kGrid, 0, reason: '${tipo.displayName} saiu da grade em x');
      expect(c.y % kGrid, 0, reason: '${tipo.displayName} saiu da grade em y');
    }
  });

  test('a âncora do AND fica na saída, à direita do toque', () {
    final st = EditorState();
    addTearDown(st.dispose);
    st.choosePaletteType(ComponentType.andGate);
    st.placeAt(const GridPoint(100, 100));

    final c = st.circuit.components.single;
    // Corpo de 50 de comprimento: a saída fica meio corpo à direita do dedo.
    expect(c.location, const GridPoint(130, 100));
    expect(c.ports.first.location, const GridPoint(130, 100));
  });
}
