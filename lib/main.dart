import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Por enquanto o editor só é pensado para retrato: a paleta e a barra de
  // modos ocupam a largura toda e o canvas fica espremido deitado. O bloqueio
  // fica aqui (e não no AndroidManifest) para que, quando houver layout de
  // paisagem, baste soltar esta lista.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  runApp(const LogiSnapApp());
}

class LogiSnapApp extends StatelessWidget {
  const LogiSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LogiSnap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
