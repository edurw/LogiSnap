// A tela fica travada em retrato enquanto não houver layout de paisagem.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logisnap/main.dart' as app;

void main() {
  testWidgets('o app pede retrato ao iniciar', (WidgetTester tester) async {
    final chamadas = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      chamadas.add(call);
      return null;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await app.main();
    await tester.pump();

    final pedido = chamadas.firstWhere(
      (c) => c.method == 'SystemChrome.setPreferredOrientations',
      orElse: () => const MethodCall('nenhuma chamada de orientação'),
    );
    expect(pedido.method, 'SystemChrome.setPreferredOrientations');
    expect(pedido.arguments, ['DeviceOrientation.portraitUp']);
  });
}
