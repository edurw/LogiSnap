import 'package:flutter/material.dart';

/// A marca do LogiSnap: uma porta AND de traço aberto.
///
/// É o mesmo desenho do ícone do app (`ic_launcher_foreground.xml`), com as
/// mesmas coordenadas no viewport de 108x108 — assim o ícone da gaveta, a
/// splash e qualquer outro lugar que use a marca não saem de sincronia.
class LogoMark extends StatelessWidget {
  final double size;
  final Color color;

  const LogoMark({super.key, this.size = 96, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LogoPainter(color)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;

  const _LogoPainter(this.color);

  /// Lado do viewport do ícone adaptativo, onde as coordenadas foram
  /// definidas.
  static const double _viewport = 108;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _viewport;
    canvas.save();
    canvas.scale(scale);

    final traco = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Corpo da porta: aresta reta à esquerda e semicírculo à direita.
    final corpo = Path()
      ..moveTo(34, 34)
      ..lineTo(54, 34)
      ..arcToPoint(const Offset(54, 74), radius: const Radius.circular(20))
      ..lineTo(34, 74)
      ..close();
    canvas.drawPath(corpo, traco);

    // Duas entradas à esquerda e a saída à direita.
    canvas.drawLine(const Offset(20, 44), const Offset(34, 44), traco);
    canvas.drawLine(const Offset(20, 64), const Offset(34, 64), traco);
    canvas.drawLine(const Offset(74, 54), const Offset(88, 54), traco);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.color != color;
}
