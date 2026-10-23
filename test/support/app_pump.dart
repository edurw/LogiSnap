import 'package:flutter_test/flutter_test.dart';
import 'package:logisnap/main.dart';
import 'package:logisnap/ui/splash_screen.dart';

/// Sobe o app e espera a splash sair, deixando o editor na tela.
///
/// Todo teste de widget que mexe no editor passa por aqui: a splash é a
/// primeira rota, então pular esse passo deixaria os `find` procurando na
/// tela errada.
Future<void> pumpEditor(WidgetTester tester) async {
  await tester.pumpWidget(const LogiSnapApp());
  await tester.pump(SplashScreen.duracao + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}
