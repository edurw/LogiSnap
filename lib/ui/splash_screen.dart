import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editor_screen.dart';
import 'logo_mark.dart';

/// Tela de abertura: a marca e o nome do app sobre a cor da identidade.
///
/// O fundo é o mesmo `#00695C` do ícone adaptativo, então a splash do sistema
/// (que no Android 12+ mostra só o ícone) emenda nesta sem piscar branco.
class SplashScreen extends StatefulWidget {
  /// Quanto tempo a tela fica visível antes de abrir o editor.
  static const Duration duracao = Duration(milliseconds: 1400);

  /// Cor de fundo, igual à do ícone do app (`ic_launcher_background`).
  static const Color fundo = Color(0xFF00695C);

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  Timer? _saida;

  @override
  void initState() {
    super.initState();
    _saida = Timer(SplashScreen.duracao, _abrirEditor);
  }

  @override
  void dispose() {
    _saida?.cancel();
    _entrada.dispose();
    super.dispose();
  }

  void _abrirEditor() {
    if (!mounted) return;
    // Substitui a rota: a splash não pode voltar com o botão Voltar.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const EditorScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aparecer = CurvedAnimation(parent: _entrada, curve: Curves.easeOut);
    // Fundo escuro pede ícones claros na barra de status; sem isto o sistema
    // mantém os ícones escuros que o tema claro do editor pede.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: SplashScreen.fundo,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: SplashScreen.fundo,
        body: Center(
          child: FadeTransition(
            opacity: aparecer,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1).animate(aparecer),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LogoMark(size: 132),
                  SizedBox(height: 24),
                  Text(
                    'LogiSnap',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Simulador de circuitos lógicos',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
