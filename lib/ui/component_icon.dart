import 'package:flutter/material.dart';

import '../core/component.dart';
import 'component_shapes.dart';

/// Miniatura do componente, desenhada com a mesma rotina do canvas.
///
/// Mostra só a silhueta — sem pinos, rótulo ou valor de simulação — escalada
/// para caber na caixa pedida. A cor padrão acompanha o texto do tema, para
/// funcionar em claro e escuro.
class ComponentIcon extends StatelessWidget {
  final ComponentType type;

  /// Caixa do ícone. As portas lógicas são mais largas que altas, então a
  /// paleta pede uma caixa levemente achatada.
  final Size size;

  final Color? color;

  const ComponentIcon(
    this.type, {
    super.key,
    this.size = const Size(28, 20),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(
        painter: _ComponentIconPainter(
          type,
          color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _ComponentIconPainter extends CustomPainter {
  final ComponentType type;
  final Color color;

  const _ComponentIconPainter(this.type, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = componentShapeBounds(type);
    // Folga para o contorno não encostar na borda da caixa.
    const margin = 2.0;
    final scale = (size.width - 2 * margin) / bounds.width;
    final scaleY = (size.height - 2 * margin) / bounds.height;
    final s = scale < scaleY ? scale : scaleY;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);
    paintComponentShape(
      canvas,
      type,
      stroke: color,
      // O traço é definido em unidades do mundo; dividir pela escala mantém
      // a espessura constante em qualquer tamanho de ícone.
      strokeWidth: 1.8 / s,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ComponentIconPainter old) =>
      old.type != type || old.color != color;
}
