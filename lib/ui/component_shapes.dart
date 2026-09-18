import 'package:flutter/material.dart';

import '../core/component.dart';

/// Desenho da silhueta dos componentes, sem nada do circuito em volta.
///
/// É a mesma rotina usada pelo canvas ([CircuitPainter]) e pelos ícones da
/// paleta ([ComponentIcon]): assim o ícone nunca sai de sincronia com o que
/// o usuário vê depois de colocar o componente.
///
/// Referencial local:
/// - portas lógicas: saída na origem e corpo crescendo para -x (o mesmo do
///   canvas, que gira o canvas conforme o `facing`);
/// - demais componentes: caixa de 20x20 centrada na origem (o canvas apenas
///   translada essa caixa para o lado certo da âncora).

/// Retângulo ocupado pela silhueta, no referencial local do tipo.
Rect componentShapeBounds(ComponentType type, {int? inputs, int? size}) {
  if (!type.isGate) {
    return Rect.fromCenter(center: Offset.zero, width: 20, height: 20);
  }
  final w = Component.axisLengthOf(type, size ?? Component.defaultSizeOf(type))
      .toDouble();
  final halfH =
      Component.bodyHalfHeightOf(type, inputs ?? Component.defaultInputsOf(type))
          .toDouble();
  return Rect.fromLTRB(-w, -halfH, 0, halfH);
}

/// Desenha a forma de [type] — só o corpo, sem pinos, rótulo nem valor.
///
/// [stroke] é o contorno, [fill] o miolo (nulo = sem preenchimento) e
/// [accent] os detalhes internos que no canvas acompanham o valor lógico
/// (onda do clock, ponto do botão, dígito da constante). [text] troca o
/// dígito da constante; por padrão vale o estado inicial dela, 1.
void paintComponentShape(
  Canvas canvas,
  ComponentType type, {
  int? inputs,
  int? size,
  required Color stroke,
  Color? fill,
  Color? accent,
  double strokeWidth = 2,
  String? text,
}) {
  final outline = Paint()
    ..color = stroke
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final body = fill == null ? null : (Paint()..color = fill);
  final detail = accent ?? stroke;

  switch (type) {
    case ComponentType.inputPin:
      final rect = Rect.fromCenter(center: Offset.zero, width: 20, height: 20);
      if (body != null) canvas.drawRect(rect, body);
      canvas.drawRect(rect, outline);
      break;

    case ComponentType.outputPin:
      if (body != null) canvas.drawCircle(Offset.zero, 10, body);
      canvas.drawCircle(Offset.zero, 10, outline);
      break;

    case ComponentType.led:
      if (body != null) canvas.drawCircle(Offset.zero, 9, body);
      canvas.drawCircle(Offset.zero, 9, outline);
      break;

    case ComponentType.button:
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 20, height: 20),
        const Radius.circular(3),
      );
      if (body != null) canvas.drawRRect(rrect, body);
      canvas.drawRRect(rrect, outline);
      canvas.drawCircle(Offset.zero, 4, Paint()..color = detail);
      break;

    case ComponentType.clock:
      final rect = Rect.fromCenter(center: Offset.zero, width: 20, height: 20);
      if (body != null) canvas.drawRect(rect, body);
      canvas.drawRect(rect, outline);
      final wave = Path()
        ..moveTo(-6, 4)
        ..lineTo(-2, 4)
        ..lineTo(-2, -4)
        ..lineTo(4, -4)
        ..lineTo(4, 4)
        ..lineTo(6, 4);
      canvas.drawPath(
        wave,
        Paint()
          ..color = detail
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      break;

    case ComponentType.constant:
      // A constante não tem corpo: o desenho dela é o próprio dígito.
      _drawGlyph(canvas, text ?? '1', detail);
      break;

    default:
      _paintGateShape(
        canvas,
        type,
        inputs: inputs ?? Component.defaultInputsOf(type),
        size: size ?? Component.defaultSizeOf(type),
        outline: outline,
        body: body,
      );
      break;
  }
}

void _drawGlyph(Canvas canvas, String text, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
}

/// Corpo das portas lógicas, no referencial da saída (origem) para as
/// entradas (x negativo).
void _paintGateShape(
  Canvas canvas,
  ComponentType type, {
  required int inputs,
  required int size,
  required Paint outline,
  Paint? body,
}) {
  final w = Component.axisLengthOf(type, size).toDouble();
  final halfH = Component.bodyHalfHeightOf(type, inputs).toDouble();

  final negated = type == ComponentType.nandGate ||
      type == ComponentType.norGate ||
      type == ComponentType.xnorGate ||
      type == ComponentType.notGate;
  // Largura do corpo sem a bolha de negação.
  final bubble = negated ? 10.0 : 0.0;
  final bodyRight = -bubble;

  switch (type) {
    case ComponentType.notGate:
    case ComponentType.bufferGate:
      final back = -w;
      final path = Path()
        ..moveTo(back, -10)
        ..lineTo(bodyRight, 0)
        ..lineTo(back, 10)
        ..close();
      if (body != null) canvas.drawPath(path, body);
      canvas.drawPath(path, outline);
      break;

    case ComponentType.andGate:
    case ComponentType.nandGate:
      final backX = -w;
      final flatRight = bodyRight - halfH; // início do arco
      final path = Path()
        ..moveTo(backX, -halfH)
        ..lineTo(flatRight, -halfH)
        ..arcToPoint(
          Offset(flatRight, halfH),
          radius: Radius.circular(halfH),
          clockwise: true,
        )
        ..lineTo(backX, halfH)
        ..close();
      if (body != null) canvas.drawPath(path, body);
      canvas.drawPath(path, outline);
      break;

    default:
      final isX =
          type == ComponentType.xorGate || type == ComponentType.xnorGate;
      // Curva traseira do corpo (côncava) e curvas frontais.
      final backX = isX ? -w + 10 : -w;
      final path = Path()
        ..moveTo(backX, -halfH)
        ..quadraticBezierTo(bodyRight - halfH * 0.9, -halfH, bodyRight, 0)
        ..quadraticBezierTo(bodyRight - halfH * 0.9, halfH, backX, halfH)
        ..quadraticBezierTo(backX + 14, 0, backX, -halfH)
        ..close();
      if (body != null) canvas.drawPath(path, body);
      canvas.drawPath(path, outline);
      if (isX) {
        final extra = Path()
          ..moveTo(backX - 10, -halfH)
          ..quadraticBezierTo(backX - 10 + 14, 0, backX - 10, halfH);
        canvas.drawPath(extra, outline);
      }
      break;
  }

  if (negated) {
    const bubbleCenter = Offset(-5, 0);
    if (body != null) canvas.drawCircle(bubbleCenter, 5, body);
    canvas.drawCircle(bubbleCenter, 5, outline);
  }
}
