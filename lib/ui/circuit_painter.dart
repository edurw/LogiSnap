import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/circuit.dart';
import '../core/component.dart';
import '../core/geometry.dart';
import '../core/simulator.dart';
import '../core/values.dart';
import '../core/wire.dart';

/// Cores dos valores lógicos, no esquema do Logisim.
Color colorOf(LogicValue v) {
  switch (v) {
    case LogicValue.zero:
      return const Color(0xFF006400);
    case LogicValue.one:
      return const Color(0xFF00CE00);
    case LogicValue.unknown:
      return const Color(0xFF5A5AFF);
    case LogicValue.error:
      return const Color(0xFFD40000);
  }
}

class CircuitPainter extends CustomPainter {
  final Circuit circuit;
  final Simulator simulator;
  final int? selectedId;
  final int? selectedWireId;

  /// Alças do fio em edição — vazio fora do modo de edição.
  final List<WireHandle> handles;
  final double zoom;
  final Offset pan;

  /// Caminho já roteado do fio sendo desenhado.
  final List<GridPoint>? wirePreview;
  final bool showPorts;

  /// Terminal marcado como origem da ligação por toques, se houver.
  final GridPoint? linkAnchor;

  CircuitPainter({
    required this.circuit,
    required this.simulator,
    required this.selectedId,
    this.selectedWireId,
    this.handles = const [],
    required this.zoom,
    required this.pan,
    this.wirePreview,
    this.showPorts = false,
    this.linkAnchor,
  });

  bool get _editing => handles.isNotEmpty;

  static final Paint _bodyPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  @override
  bool shouldRepaint(covariant CircuitPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFAFAF5),
    );
    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);

    _paintGrid(canvas, size);
    _paintWires(canvas);
    for (final c in circuit.components) {
      _paintComponent(canvas, c);
    }
    _paintJunctions(canvas);
    if (showPorts) _paintPorts(canvas);
    _paintSelection(canvas);
    _paintWirePreview(canvas);
    _paintHandles(canvas);

    canvas.restore();
  }

  // ------------------------------------------------------------- Grade

  void _paintGrid(Canvas canvas, Size size) {
    final step = zoom >= 0.75 ? kGrid : kGrid * 5;
    final paint = Paint()..color = const Color(0xFFB9B9B0);
    final topLeft = (-pan) / zoom;
    final bottomRight = (Offset(size.width, size.height) - pan) / zoom;
    final x0 = (topLeft.dx / step).floor() * step;
    final y0 = (topLeft.dy / step).floor() * step;
    final dots = <Offset>[];
    for (double x = x0.toDouble(); x <= bottomRight.dx; x += step) {
      for (double y = y0.toDouble(); y <= bottomRight.dy; y += step) {
        dots.add(Offset(x, y));
      }
      if (dots.length > 20000) break;
    }
    canvas.drawPoints(
        ui.PointMode.points, dots, paint..strokeWidth = 1.6 / zoom);
  }

  // ------------------------------------------------------------- Fios

  Path _pathOf(Wire w) {
    final path = Path()..moveTo(w.start.x.toDouble(), w.start.y.toDouble());
    for (final p in w.points.skip(1)) {
      path.lineTo(p.x.toDouble(), p.y.toDouble());
    }
    return path;
  }

  void _paintWires(Canvas canvas) {
    for (final w in circuit.wires) {
      final path = _pathOf(w);
      // Realce do fio selecionado, por baixo do traço. Em edição ele fica mais
      // forte e mais largo, para o modo se anunciar.
      if (w.id == selectedWireId) {
        canvas.drawPath(
          path,
          Paint()
            ..color = _editing
                ? const Color(0x992962FF)
                : const Color(0x662962FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = _editing ? 15 : 11
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colorOf(simulator.valueOfWire(w))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Marca os pontos onde há de fato uma conexão: uma ponta de fio encostando
  /// em outro fio, ou uma porta de componente sobre o meio de um fio. Curvas e
  /// cruzamentos simples não ganham marca, porque não conectam nada.
  void _paintJunctions(Canvas canvas) {
    final junctions = <GridPoint, LogicValue>{};
    for (final w in circuit.wires) {
      for (final e in w.endpoints) {
        for (final other in circuit.wires) {
          if (identical(other, w)) continue;
          if (other.contains(e)) {
            junctions[e] = simulator.valueOfWire(w);
            break;
          }
        }
      }
      for (final c in circuit.components) {
        for (final port in c.ports) {
          if (w.containsInterior(port.location)) {
            junctions[port.location] = simulator.valueOfWire(w);
          }
        }
      }
    }
    junctions.forEach((p, v) {
      canvas.drawCircle(
        Offset(p.x.toDouble(), p.y.toDouble()),
        4,
        Paint()..color = colorOf(v),
      );
    });
  }

  void _paintPorts(Canvas canvas) {
    final paint = Paint()..color = const Color(0x885A5AFF);
    for (final c in circuit.components) {
      for (final p in c.ports) {
        canvas.drawCircle(
          Offset(p.location.x.toDouble(), p.location.y.toDouble()),
          3,
          paint,
        );
      }
    }
    final anchor = linkAnchor;
    if (anchor != null) {
      // Origem marcada: anel bem visível para não restar dúvida de onde o
      // próximo toque vai ligar.
      final at = Offset(anchor.x.toDouble(), anchor.y.toDouble());
      canvas.drawCircle(at, 5, Paint()..color = const Color(0xFF00695C));
      canvas.drawCircle(
        at,
        9,
        Paint()
          ..color = const Color(0xFF00695C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _paintWirePreview(Canvas canvas) {
    final path = wirePreview;
    if (path == null || path.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xAA555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i + 1 < path.length; i++) {
      canvas.drawLine(_o(path[i]), _o(path[i + 1]), paint);
    }
    canvas.drawCircle(
      _o(path.first),
      4,
      Paint()..color = const Color(0xAA555555),
    );
  }

  // ------------------------------------------------------- Alças de edição

  /// Desenha as alças com raio constante em pixels de tela: o canvas está
  /// escalado pelo zoom, então o raio do mundo é dividido por ele.
  void _paintHandles(Canvas canvas) {
    if (!_editing) return;
    final r = 9 / zoom;
    final fill = Paint()..color = const Color(0xFF2962FF);
    final hollow = Paint()
      ..color = const Color(0xFF2962FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / zoom;
    final white = Paint()..color = Colors.white;

    for (final h in handles) {
      final c = _o(h.at);
      if (h.isSegment) {
        // Meio do trecho: círculo vazado — arrastar cria uma curva nova.
        canvas.drawCircle(c, r * 0.7, white);
        canvas.drawCircle(c, r * 0.7, hollow);
      } else {
        // Vértice: quadrado cheio — arrastar move a curva ou a ponta.
        final rect = Rect.fromCenter(center: c, width: r * 2, height: r * 2);
        canvas.drawRect(rect, white);
        canvas.drawRect(rect.deflate(1.5 / zoom), fill);
      }
    }
  }

  Offset _o(GridPoint p) => Offset(p.x.toDouble(), p.y.toDouble());

  // ------------------------------------------------------------- Seleção

  void _paintSelection(Canvas canvas) {
    final id = selectedId;
    if (id == null) return;
    Component? c;
    for (final e in circuit.components) {
      if (e.id == id) {
        c = e;
        break;
      }
    }
    if (c == null) return;
    final b = circuit.boundsOf(c);
    final rect = Rect.fromLTRB(
      b[0].toDouble() - 4,
      b[1].toDouble() - 4,
      b[2].toDouble() + 4,
      b[3].toDouble() + 4,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0x332962FF)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF2962FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ------------------------------------------------------------- Componentes

  void _paintComponent(Canvas canvas, Component c) {
    canvas.save();
    canvas.translate(c.x.toDouble(), c.y.toDouble());

    switch (c.type) {
      case ComponentType.inputPin:
        _paintPin(canvas, c, isOutput: false);
        break;
      case ComponentType.outputPin:
        _paintPin(canvas, c, isOutput: true);
        break;
      case ComponentType.led:
        _paintLed(canvas, c);
        break;
      case ComponentType.button:
        _paintButton(canvas, c);
        break;
      case ComponentType.clock:
        _paintClock(canvas, c);
        break;
      case ComponentType.constant:
        _paintConstant(canvas, c);
        break;
      default:
        canvas.rotate(c.facing.angle);
        _paintGate(canvas, c);
        break;
    }
    canvas.restore();
    _paintLabel(canvas, c);
  }

  void _paintLabel(Canvas canvas, Component c) {
    if (c.label.isEmpty) return;
    final b = circuit.boundsOf(c);
    _drawText(
      canvas,
      c.label,
      Offset((b[0] + b[2]) / 2, b[1] - 12),
      color: Colors.black87,
      fontSize: 11,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    Color color = Colors.black,
    double fontSize = 12,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Corpo atrás da âncora, no referencial local do componente
  /// (+x = direção do facing). Usado por pino, LED, botão, clock.
  Rect _behindRect(Component c, {double halfSide = 10}) {
    switch (c.facing) {
      case Facing.east:
        return Rect.fromLTRB(-2 * halfSide, -halfSide, 0, halfSide);
      case Facing.west:
        return Rect.fromLTRB(0, -halfSide, 2 * halfSide, halfSide);
      case Facing.north:
        return Rect.fromLTRB(-halfSide, 0, halfSide, 2 * halfSide);
      case Facing.south:
        return Rect.fromLTRB(-halfSide, -2 * halfSide, halfSide, 0);
    }
  }

  void _paintPin(Canvas canvas, Component c, {required bool isOutput}) {
    final v = isOutput
        ? simulator.displayValueOf(c)
        : c.state;
    final rect = _behindRect(c);
    final fill = Paint()..color = const Color(0xFFF0F0E8);
    if (isOutput) {
      canvas.drawCircle(rect.center, 10, fill);
      canvas.drawCircle(rect.center, 10, _bodyPaint);
      canvas.drawCircle(rect.center, 7,
          Paint()..color = colorOf(v).withAlpha(60));
    } else {
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, _bodyPaint);
    }
    _drawText(
      canvas,
      _digit(v),
      rect.center,
      color: colorOf(v),
      bold: true,
      fontSize: 13,
    );
  }

  String _digit(LogicValue v) {
    switch (v) {
      case LogicValue.zero:
        return '0';
      case LogicValue.one:
        return '1';
      case LogicValue.unknown:
        return 'x';
      case LogicValue.error:
        return 'E';
    }
  }

  void _paintLed(Canvas canvas, Component c) {
    final v = simulator.displayValueOf(c);
    final rect = _behindRect(c);
    final on = v == LogicValue.one;
    final color = v == LogicValue.error
        ? const Color(0xFFD40000)
        : on
            ? const Color(0xFFFF3020)
            : const Color(0xFF551510);
    canvas.drawCircle(rect.center, 9, Paint()..color = color);
    canvas.drawCircle(rect.center, 9, _bodyPaint);
    if (on) {
      canvas.drawCircle(
        rect.center,
        13,
        Paint()..color = const Color(0x55FF5040),
      );
    }
  }

  void _paintButton(Canvas canvas, Component c) {
    final rect = _behindRect(c);
    final pressed = c.state == LogicValue.one;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = pressed ? const Color(0xFFB0D0B0) : const Color(0xFFE8E8E0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      _bodyPaint,
    );
    canvas.drawCircle(rect.center, 4,
        Paint()..color = pressed ? const Color(0xFF00A000) : Colors.black54);
  }

  void _paintClock(Canvas canvas, Component c) {
    final rect = _behindRect(c);
    canvas.drawRect(rect, Paint()..color = const Color(0xFFF0F0E8));
    canvas.drawRect(rect, _bodyPaint);
    final wave = Path()
      ..moveTo(rect.left + 4, rect.center.dy + 4)
      ..lineTo(rect.center.dx - 2, rect.center.dy + 4)
      ..lineTo(rect.center.dx - 2, rect.center.dy - 4)
      ..lineTo(rect.center.dx + 4, rect.center.dy - 4)
      ..lineTo(rect.center.dx + 4, rect.center.dy + 4)
      ..lineTo(rect.right - 4, rect.center.dy + 4);
    canvas.drawPath(
      wave,
      Paint()
        ..color = colorOf(c.state)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  void _paintConstant(Canvas canvas, Component c) {
    _drawText(
      canvas,
      _digit(c.state),
      _behindRect(c, halfSide: 7).center,
      color: colorOf(c.state),
      bold: true,
      fontSize: 15,
    );
  }

  // ------------------------------------------------------------- Portas
  // Desenhadas no referencial local: saída na origem, entradas em x < 0.

  void _paintGate(Canvas canvas, Component c) {
    final w = c.axisLength.toDouble();
    final offsets = c.type.isMultiInputGate
        ? Component.inputOffsets(c.inputs)
        : const [0];
    // Mesma medida que Circuit.boundsOf usa, para o retângulo de seleção e a
    // área de toque não descolarem do desenho.
    final halfH = c.bodyHalfHeight.toDouble();

    final negated = c.type == ComponentType.nandGate ||
        c.type == ComponentType.norGate ||
        c.type == ComponentType.xnorGate ||
        c.type == ComponentType.notGate;
    // Largura do corpo sem a bolha de negação.
    final bubble = negated ? 10.0 : 0.0;
    final bodyRight = -bubble;

    switch (c.type) {
      case ComponentType.notGate:
      case ComponentType.bufferGate:
        final back = -w;
        final path = Path()
          ..moveTo(back, -10)
          ..lineTo(bodyRight, 0)
          ..lineTo(back, 10)
          ..close();
        canvas.drawPath(path, Paint()..color = Colors.white);
        canvas.drawPath(path, _bodyPaint);
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
        canvas.drawPath(path, Paint()..color = Colors.white);
        canvas.drawPath(path, _bodyPaint);
        break;

      case ComponentType.orGate:
      case ComponentType.norGate:
      case ComponentType.xorGate:
      case ComponentType.xnorGate:
        final isX = c.type == ComponentType.xorGate ||
            c.type == ComponentType.xnorGate;
        // Curva traseira do corpo (côncava) e curvas frontais.
        final backX = isX ? -w + 10 : -w;
        final path = Path()
          ..moveTo(backX, -halfH)
          ..quadraticBezierTo(bodyRight - halfH * 0.9, -halfH, bodyRight, 0)
          ..quadraticBezierTo(bodyRight - halfH * 0.9, halfH, backX, halfH)
          ..quadraticBezierTo(backX + 14, 0, backX, -halfH)
          ..close();
        canvas.drawPath(path, Paint()..color = Colors.white);
        canvas.drawPath(path, _bodyPaint);
        if (isX) {
          final extra = Path()
            ..moveTo(backX - 10, -halfH)
            ..quadraticBezierTo(backX - 10 + 14, 0, backX - 10, halfH);
          canvas.drawPath(extra, _bodyPaint);
        }
        break;

      default:
        break;
    }

    if (negated) {
      canvas.drawCircle(const Offset(-5, 0), 5, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(-5, 0), 5, _bodyPaint);
    }

    // Pernas das entradas até o corpo (quando o corpo é mais estreito que a
    // distribuição das entradas).
    for (final o in offsets) {
      final oy = o.toDouble();
      if (oy.abs() > halfH - 2) {
        canvas.drawLine(
          Offset(-w, oy),
          Offset(-w + 6, oy),
          _bodyPaint,
        );
      }
    }
  }
}
