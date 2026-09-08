import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/geometry.dart';
import '../core/wire.dart';
import '../state/editor_state.dart';
import 'circuit_painter.dart';

/// Área de edição: desenha o circuito e traduz gestos de toque em ações.
///
/// Gestos:
/// - dois dedos: pan e zoom (em qualquer modo);
/// - um dedo arrastando: pan (modos interagir/apagar/adicionar), mover
///   componente ou fio (modo selecionar) ou desenhar fio (modo fio);
/// - toque simples: ação do modo ativo.
class CircuitCanvas extends StatefulWidget {
  final EditorState state;
  const CircuitCanvas({super.key, required this.state});

  @override
  State<CircuitCanvas> createState() => _CircuitCanvasState();
}

class _CircuitCanvasState extends State<CircuitCanvas> {
  /// Enquadramento inicial — e para onde "centralizar" volta quando não há
  /// nada desenhado.
  static const Offset _initialPan = Offset(60, 80);
  static const double _initialZoom = 1.6;
  static const double _minZoom = 0.35;
  static const double _maxZoom = 4.0;

  Offset _pan = _initialPan;
  double _zoom = _initialZoom;

  // Estado transitório dos gestos.
  double _zoomAtGestureStart = _initialZoom;
  Offset? _wireStart;
  Offset? _wireEnd;

  /// Eixo que o traço vai percorrer primeiro, travado no primeiro movimento
  /// do dedo que passa de uma casa da grade.
  RouteAxis? _wireAxis;

  bool _draggingSelection = false;
  bool _draggingHandle = false;
  bool _panning = false;
  int _pointers = 0;

  /// Tolerância das alças em unidades do mundo: dividida pelo zoom, o alvo
  /// tem sempre o mesmo tamanho no dedo.
  int get _handleSlop =>
      (EditorState.handleTouchSlop / _zoom).round().clamp(4, 60);

  EditorState get st => widget.state;

  Offset _toWorld(Offset screen) => (screen - _pan) / _zoom;

  /// Ponto encaixado na grade — usado para criar coisas (fios, componentes).
  GridPoint _snapPoint(Offset world) =>
      GridPoint(snap(world.dx), snap(world.dy));

  /// Ponto exato do toque, sem encaixar na grade — usado para acertar o que
  /// está embaixo do dedo, onde o encaixe atrapalharia a tolerância.
  GridPoint _hitPoint(Offset world) =>
      GridPoint(world.dx.round(), world.dy.round());

  @override
  Widget build(BuildContext context) {
    final canvas = Listener(
      onPointerDown: (_) => _pointers++,
      onPointerUp: (_) => _pointers = (_pointers - 1).clamp(0, 10),
      onPointerCancel: (_) => _pointers = (_pointers - 1).clamp(0, 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: () => st.pressUpAll(),
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: AnimatedBuilder(
          animation: st,
          builder: (context, _) {
            List<GridPoint>? preview;
            if (_wireStart != null && _wireEnd != null) {
              final a = _snapPoint(_toWorld(_wireStart!));
              final b = _snapPoint(_toWorld(_wireEnd!));
              if (a != b) {
                preview = Wire.routePath(a, b, firstAxis: _wireAxis);
              }
            }
            return CustomPaint(
              size: Size.infinite,
              painter: CircuitPainter(
                circuit: st.circuit,
                simulator: st.simulator,
                selectedId: st.selectedId,
                selectedWireId: st.selectedWireId,
                handles: st.wireHandles,
                zoom: _zoom,
                pan: _pan,
                wirePreview: preview,
                // Com um fio selecionado no modo Mover os terminais aparecem
                // como no modo Fio: é neles que as pontas precisam encaixar.
                showPorts: st.mode == EditorMode.wire ||
                    (st.mode == EditorMode.select && st.selectedWire != null),
              ),
            );
          },
        ),
      ),
    );

    // O botão de centralizar fica sobre o canvas, no canto inferior direito:
    // longe das barras de seleção (topo) e ao alcance do polegar.
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(child: canvas),
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: null,
              tooltip: 'Centralizar',
              onPressed: () => _centerView(constraints.biggest),
              child: const Icon(Icons.center_focus_strong),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- Enquadramento

  /// Retângulo que envolve tudo o que está desenhado, em coordenadas do
  /// mundo. Null quando o circuito está vazio.
  Rect? _contentBounds() {
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    void include(num x, num y) {
      if (x < minX) minX = x.toDouble();
      if (y < minY) minY = y.toDouble();
      if (x > maxX) maxX = x.toDouble();
      if (y > maxY) maxY = y.toDouble();
    }

    for (final c in st.circuit.components) {
      final b = st.circuit.boundsOf(c);
      include(b[0], b[1]);
      include(b[2], b[3]);
    }
    for (final w in st.circuit.wires) {
      for (final p in w.points) {
        include(p.x, p.y);
      }
    }
    if (minX > maxX) return null;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Traz o circuito inteiro para o meio da tela.
  ///
  /// O zoom só diminui, e apenas quando o circuito não cabe: aproximar por
  /// conta própria tiraria a referência de quem está trabalhando de perto.
  /// Sem nada desenhado, volta ao enquadramento inicial.
  void _centerView(Size view) {
    final bounds = _contentBounds();
    if (bounds == null || view.isEmpty) {
      setState(() {
        _pan = _initialPan;
        _zoom = _initialZoom;
      });
      return;
    }
    // Margem para o circuito não encostar nas bordas nem sumir atrás do
    // próprio botão.
    const margin = 40.0;
    final availableW = math.max(view.width - 2 * margin, 1.0);
    final availableH = math.max(view.height - 2 * margin, 1.0);
    final fit = math.min(
      availableW / math.max(bounds.width, 1.0),
      availableH / math.max(bounds.height, 1.0),
    );
    setState(() {
      if (fit < _zoom) _zoom = fit.clamp(_minZoom, _maxZoom).toDouble();
      _pan = view.center(Offset.zero) - bounds.center * _zoom;
    });
  }

  // ------------------------------------------------------------- Toques

  void _onTapDown(TapDownDetails d) {
    if (st.mode == EditorMode.interact) {
      st.pressDownAt(_hitPoint(_toWorld(d.localPosition)));
    }
  }

  void _onTapUp(TapUpDetails d) {
    final world = _toWorld(d.localPosition);
    switch (st.mode) {
      case EditorMode.interact:
        st.pressUpAll();
        st.pokeAt(_hitPoint(world));
        break;
      case EditorMode.select:
        // Editando: só o botão "Concluir" sai do modo, para um toque fora do
        // fio não desfazer a seleção no meio do ajuste.
        if (!st.editingWire) st.selectAt(_hitPoint(world));
        break;
      case EditorMode.erase:
        st.eraseAt(_hitPoint(world));
        break;
      case EditorMode.place:
        st.placeAt(_snapPoint(world));
        break;
      case EditorMode.wire:
        break;
    }
  }

  // ------------------------------------------------------------- Arrastos

  /// Alça mais próxima de [p] dentro da tolerância. Vértice ganha de ponto
  /// médio no empate: mover uma curva é mais comum que criar uma nova.
  WireHandle? _handleAt(GridPoint p) {
    final slop = _handleSlop;
    WireHandle? best;
    var bestDist = 1 << 30;
    for (final h in st.wireHandles) {
      final d = (h.at.x - p.x).abs() + (h.at.y - p.y).abs();
      if (d > slop) continue;
      final better = d < bestDist ||
          (d == bestDist && best != null && best.isSegment && !h.isSegment);
      if (better) {
        bestDist = d;
        best = h;
      }
    }
    return best;
  }

  void _onScaleStart(ScaleStartDetails d) {
    st.pressUpAll();
    _zoomAtGestureStart = _zoom;
    _wireStart = null;
    _wireEnd = null;
    _wireAxis = null;
    _draggingSelection = false;
    _draggingHandle = false;
    _panning = false;

    if (d.pointerCount >= 2 || _pointers >= 2) {
      _panning = true;
      return;
    }

    final world = _toWorld(d.localFocalPoint);
    final hitAt = _hitPoint(world);
    switch (st.mode) {
      case EditorMode.wire:
        _wireStart = d.localFocalPoint;
        _wireEnd = d.localFocalPoint;
        break;
      case EditorMode.select when st.editingWire:
        final handle = _handleAt(hitAt);
        if (handle != null) {
          st.beginHandleDrag(handle);
          _draggingHandle = true;
        } else {
          // Fora das alças o dedo continua servindo para navegar.
          _panning = true;
        }
        break;
      case EditorMode.select:
        final hit = st.circuit.componentAt(hitAt,
            tolerance: EditorState.componentTouchSlop);
        final hitWire = hit == null
            ? st.circuit.wireAt(hitAt, tolerance: EditorState.wireTouchSlop)
            : null;
        if (hit != null || hitWire != null) {
          st.selectedId = hit?.id;
          st.selectedWireId = hitWire?.id;
          // Âncora encaixada na grade: o deslocamento do fio sai múltiplo
          // de kGrid e ele nunca sai do alinhamento.
          st.beginMove(_snapPoint(world));
          _draggingSelection = true;
        } else {
          _panning = true;
        }
        break;
      default:
        _panning = true;
    }
    setState(() {});
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      // Zoom + pan com dois dedos, ancorado no ponto focal.
      final newZoom =
          (_zoomAtGestureStart * d.scale).clamp(_minZoom, _maxZoom).toDouble();
      final focalWorld = (d.localFocalPoint - _pan) / _zoom;
      _zoom = newZoom;
      // Mantém o ponto do mundo sob o foco do gesto (isto também acompanha
      // o deslocamento do foco, cobrindo o pan com dois dedos).
      _pan = d.localFocalPoint - focalWorld * _zoom;
      // Cancela interações de um dedo em andamento.
      _wireStart = null;
      _wireEnd = null;
      _wireAxis = null;
      if (_draggingSelection) {
        st.endMove();
        _draggingSelection = false;
      }
      if (_draggingHandle) {
        st.endHandleDrag();
        _draggingHandle = false;
      }
      setState(() {});
      return;
    }

    if (_wireStart != null) {
      _wireEnd = d.localFocalPoint;
      // O eixo trava na primeira direção que passar de uma casa da grade,
      // medida no mundo para o zoom não mudar a sensação do gesto.
      if (_wireAxis == null) {
        final delta = _toWorld(_wireEnd!) - _toWorld(_wireStart!);
        if (delta.distance >= kGrid) {
          _wireAxis = delta.dx.abs() >= delta.dy.abs()
              ? RouteAxis.horizontal
              : RouteAxis.vertical;
        }
      }
      setState(() {});
      return;
    }
    if (_draggingHandle) {
      st.dragHandleTo(_snapPoint(_toWorld(d.localFocalPoint)));
      return;
    }
    if (_draggingSelection) {
      st.moveTo(_snapPoint(_toWorld(d.localFocalPoint)));
      return;
    }
    if (_panning) {
      _pan += d.focalPointDelta;
      setState(() {});
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_wireStart != null && _wireEnd != null) {
      final a = _snapPoint(_toWorld(_wireStart!));
      final b = _snapPoint(_toWorld(_wireEnd!));
      if (a != b) st.addWirePath(a, b, firstAxis: _wireAxis);
    }
    _wireStart = null;
    _wireEnd = null;
    _wireAxis = null;
    if (_draggingSelection) {
      st.endMove();
      _draggingSelection = false;
    }
    if (_draggingHandle) {
      st.endHandleDrag();
      _draggingHandle = false;
    }
    _panning = false;
    setState(() {});
  }
}
