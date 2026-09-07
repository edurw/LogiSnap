import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/circuit.dart';
import '../core/component.dart';
import '../core/geometry.dart';
import '../core/serialization.dart';
import '../core/simulator.dart';
import '../core/values.dart';
import '../core/wire.dart';

/// Ferramenta ativa no editor.
enum EditorMode {
  /// Interagir com o circuito (tocar pinos/botões — o "poke" do Logisim).
  interact,

  /// Selecionar e mover componentes.
  select,

  /// Desenhar fios.
  wire,

  /// Apagar componentes e fios.
  erase,

  /// Adicionar o componente escolhido na paleta.
  place,
}

/// Um fio preso a uma porta do componente que está mudando de lugar.
///
/// [base] é o traçado de antes do movimento: cada atualização é recalculada a
/// partir dele, nunca do resultado anterior.
class _WireLink {
  final Wire base;
  final int? startPortIndex;
  final int? endPortIndex;
  const _WireLink(this.base, this.startPortIndex, this.endPortIndex);
}

/// Estado central do editor (circuito + simulação + ferramentas).
class EditorState extends ChangeNotifier {
  Circuit circuit = Circuit();
  late Simulator simulator = Simulator(circuit);

  EditorMode mode = EditorMode.interact;
  ComponentType? pendingType;

  /// Componente selecionado, ou null. Nunca fica preenchido junto com
  /// [selectedWireId].
  int? selectedId;

  /// Fio selecionado, ou null.
  int? selectedWireId;

  /// Modo de edição do traçado do fio selecionado, ligado pelo botão "Editar".
  /// Enquanto ativo, o fio mostra alças e o arraste mexe nelas.
  bool editingWire = false;

  String? currentFileName;
  bool dirty = false;

  final List<String> _undoStack = [];
  static const int _maxUndo = 50;

  /// Folga (em unidades do mundo) para acertar um fio com o dedo — o traço tem
  /// só 3 de espessura, então precisa de uma margem maior.
  static const int wireTouchSlop = 8;

  /// Folga em volta do corpo do componente. Pequena de propósito: a área de
  /// toque fica praticamente do tamanho do desenho.
  static const int componentTouchSlop = 4;

  /// Raio de toque das alças de edição, em pixels de tela. O canvas divide
  /// pelo zoom para o alvo ter sempre o mesmo tamanho no dedo.
  static const double handleTouchSlop = 14;

  // ------------------------------------------------------------ Clock
  Timer? _clockTimer;
  bool clockRunning = false;

  /// Frequência do clock em meios-ciclos por segundo.
  double clockHz = 2;

  Component? get selected {
    if (selectedId == null) return null;
    for (final c in circuit.components) {
      if (c.id == selectedId) return c;
    }
    return null;
  }

  Wire? get selectedWire {
    final id = selectedWireId;
    return id == null ? null : circuit.wireById(id);
  }

  bool get hasSelection => selected != null || selectedWire != null;

  /// Alças do fio em edição — vazio fora do modo de edição.
  List<WireHandle> get wireHandles =>
      editingWire ? (selectedWire?.handles ?? const []) : const [];

  void clearSelection() {
    selectedId = null;
    selectedWireId = null;
    editingWire = false;
  }

  // ------------------------------------------------------------ Ferramentas

  void setMode(EditorMode m) {
    mode = m;
    if (m != EditorMode.place) pendingType = null;
    if (m != EditorMode.select) clearSelection();
    notifyListeners();
  }

  void choosePaletteType(ComponentType type) {
    pendingType = type;
    mode = EditorMode.place;
    clearSelection();
    notifyListeners();
  }

  // ------------------------------------------------------------ Undo

  void _pushUndo() {
    _undoStack.add(CircuitJson.encode(circuit));
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    dirty = true;
  }

  bool get canUndo => _undoStack.isNotEmpty;

  void undo() {
    if (_undoStack.isEmpty) return;
    final snapshot = _undoStack.removeLast();
    final name = circuit.name;
    circuit = CircuitJson.decode(snapshot)..name = name;
    simulator = Simulator(circuit);
    clearSelection();
    notifyListeners();
  }

  void _structureChanged() {
    simulator.rebuild();
    notifyListeners();
  }

  // ------------------------------------------------------------ Edição

  void placeAt(GridPoint p) {
    final type = pendingType;
    if (type == null) return;
    _pushUndo();
    circuit.addComponent(Component(
      id: circuit.newId(),
      type: type,
      x: p.x,
      y: p.y,
      facing: type == ComponentType.led ? Facing.west : Facing.east,
    ));
    _structureChanged();
  }

  /// Seleciona o que estiver em [p]: componente primeiro, senão o fio inteiro.
  void selectAt(GridPoint p) {
    final c = circuit.componentAt(p, tolerance: componentTouchSlop);
    final w = c == null ? circuit.wireAt(p, tolerance: wireTouchSlop) : null;
    // Trocar de seleção sai do modo de edição: modo escondido que sobrevive à
    // troca é fonte de confusão.
    if (c?.id != selectedId || w?.id != selectedWireId) editingWire = false;
    selectedId = c?.id;
    selectedWireId = w?.id;
    notifyListeners();
  }

  bool _moving = false;
  GridPoint? _moveAnchor;

  void beginMove(GridPoint at) {
    if (!hasSelection) return;
    _pushUndo();
    _moving = true;
    _moveAnchor = at;
    final c = selected;
    _moveLinks = c == null ? const [] : _linksFor(c);
  }

  /// Arrasta o que está selecionado. O componente acompanha o dedo pela sua
  /// âncora, levando junto os fios presos às suas portas; o fio selecionado
  /// sozinho é deslocado inteiro, mantendo o traçado.
  void moveTo(GridPoint p) {
    if (!_moving) return;
    final c = selected;
    if (c != null) {
      c.x = p.x;
      c.y = p.y;
      _applyLinks(c, _moveLinks);
      _moveAnchor = p;
      _structureChanged();
      return;
    }
    final w = selectedWire;
    final anchor = _moveAnchor;
    if (w != null && anchor != null) {
      if (p == anchor) return;
      circuit.replaceWire(w.translated(p.x - anchor.x, p.y - anchor.y));
      _moveAnchor = p;
      _structureChanged();
    }
  }

  void endMove() {
    _moving = false;
    _moveAnchor = null;
    _moveLinks = const [];
  }

  // -------------------------------------------------- Edição do traçado

  void startWireEdit() {
    if (selectedWire == null) return;
    editingWire = true;
    notifyListeners();
  }

  void endWireEdit() {
    editingWire = false;
    notifyListeners();
  }

  /// O fio como estava quando o arraste da alça começou.
  ///
  /// Cada atualização é recalculada a partir dele, nunca do resultado
  /// anterior: [Wire.moveVertex] e [Wire.slideSegment] inserem e removem
  /// pontos, então o índice da alça mudaria depois da primeira aplicação e o
  /// dedo passaria a arrastar a alça errada.
  Wire? _handleBase;
  int _handleIndex = 0;
  bool _handleIsSegment = false;

  bool get draggingHandle => _handleBase != null;

  void beginHandleDrag(WireHandle handle) {
    final w = selectedWire;
    if (w == null) return;
    _pushUndo();
    _handleBase = w;
    _handleIndex = handle.index;
    _handleIsSegment = handle.isSegment;
  }

  void dragHandleTo(GridPoint p) {
    final base = _handleBase;
    if (base == null) return;
    final edited = _handleIsSegment
        ? base.slideSegment(_handleIndex, p)
        : base.moveVertex(_handleIndex, p);
    circuit.replaceWire(edited);
    _structureChanged();
  }

  void endHandleDrag() => _handleBase = null;

  // ------------------------------------- Fios que acompanham o componente

  /// Fios presos às portas do componente que está sendo arrastado, como
  /// estavam no início do arraste.
  List<_WireLink> _moveLinks = const [];

  /// Descobre quais fios têm uma ponta em cima de uma porta de [c].
  ///
  /// Precisa ser chamado **antes** de mexer no componente: depois disso as
  /// portas já andaram e nada mais bate.
  List<_WireLink> _linksFor(Component c) {
    final byLocation = <GridPoint, int>{};
    for (final p in c.ports) {
      byLocation[p.location] = p.index;
    }
    final links = <_WireLink>[];
    for (final w in circuit.wires) {
      final startPort = byLocation[w.start];
      final endPort = byLocation[w.end];
      // Um fio com as duas pontas no mesmo componente vira um link só: dois
      // links separados se sobrescreveriam.
      if (startPort == null && endPort == null) continue;
      links.add(_WireLink(w, startPort, endPort));
    }
    return links;
  }

  /// Leva as pontas presas para onde as portas de [c] estão agora.
  void _applyLinks(Component c, List<_WireLink> links) {
    if (links.isEmpty) return;
    final ports = {for (final p in c.ports) p.index: p.location};
    for (final link in links) {
      // A porta pode ter sumido (reduzir o nº de entradas): deixa o fio quieto.
      final start =
          link.startPortIndex == null ? null : ports[link.startPortIndex];
      final end = link.endPortIndex == null ? null : ports[link.endPortIndex];
      if (start == null && end == null) continue;
      final edited = link.base.withEndpoints(start: start, end: end);
      // Pontas colapsando no mesmo ponto degeneram o fio; como cada quadro
      // recalcula a partir da base, o quadro seguinte se recupera sozinho.
      if (edited.isDegenerate) continue;
      circuit.replaceWire(edited);
    }
  }

  void rotateSelected() {
    final c = selected;
    if (c == null) return;
    _pushUndo();
    final links = _linksFor(c);
    c.facing = c.facing.rotatedClockwise;
    _applyLinks(c, links);
    _structureChanged();
  }

  void setSelectedInputs(int n) {
    final c = selected;
    if (c == null || !c.type.isMultiInputGate) return;
    _pushUndo();
    final links = _linksFor(c);
    c.inputs = n.clamp(2, 8);
    _applyLinks(c, links);
    _structureChanged();
  }

  void setSelectedLabel(String label) {
    final c = selected;
    if (c == null) return;
    _pushUndo();
    c.label = label;
    _structureChanged();
  }

  /// Apaga o componente ou o fio selecionado. O fio sai inteiro, com curvas e
  /// tudo.
  void deleteSelected() {
    final c = selected;
    if (c != null) {
      _pushUndo();
      circuit.removeComponent(c);
      clearSelection();
      _structureChanged();
      return;
    }
    final w = selectedWire;
    if (w != null) {
      _pushUndo();
      circuit.removeWire(w);
      clearSelection();
      _structureChanged();
    }
  }

  void duplicateSelected() {
    final c = selected;
    if (c != null) {
      _pushUndo();
      final copy = c.copy(id: circuit.newId())
        ..x = c.x + 40
        ..y = c.y + 40;
      circuit.addComponent(copy);
      selectedId = copy.id;
      _structureChanged();
      return;
    }
    final w = selectedWire;
    if (w != null) {
      _pushUndo();
      final copy = circuit
          .addWirePath([for (final p in w.points) p.translate(40, 40)]);
      if (copy != null) selectedWireId = copy.id;
      _structureChanged();
    }
  }

  /// Cria um fio entre dois pontos, roteado em L. O caminho inteiro — com
  /// curva ou sem — vira um único fio.
  ///
  /// [firstAxis] é a direção do primeiro movimento do dedo, o que permite dois
  /// traçados diferentes para o mesmo par de pontos.
  void addWirePath(GridPoint from, GridPoint to, {RouteAxis? firstAxis}) {
    if (from == to) return;
    _pushUndo();
    circuit.addRoutedWire(from, to, firstAxis: firstAxis);
    _structureChanged();
  }

  void eraseAt(GridPoint p) {
    final c = circuit.componentAt(p, tolerance: componentTouchSlop);
    if (c != null) {
      _pushUndo();
      circuit.removeComponent(c);
      if (selectedId == c.id) clearSelection();
      _structureChanged();
      return;
    }
    final w = circuit.wireAt(p, tolerance: wireTouchSlop);
    if (w != null) {
      _pushUndo();
      circuit.removeWire(w);
      if (selectedWireId == w.id) clearSelection();
      _structureChanged();
    }
  }

  // ------------------------------------------------------------ Interação

  /// Toque no modo interagir ("poke").
  void pokeAt(GridPoint p) {
    final c = circuit.componentAt(p, tolerance: componentTouchSlop);
    if (c == null) return;
    switch (c.type) {
      case ComponentType.inputPin:
      case ComponentType.clock:
      case ComponentType.constant:
        c.state = c.state == LogicValue.one ? LogicValue.zero : LogicValue.one;
        dirty = true;
        simulator.propagate();
        notifyListeners();
        break;
      case ComponentType.button:
        // Botão é tratado em pressDown/pressUp.
        break;
      default:
        break;
    }
  }

  void pressDownAt(GridPoint p) {
    final c = circuit.componentAt(p, tolerance: componentTouchSlop);
    if (c != null && c.type == ComponentType.button) {
      c.state = LogicValue.one;
      simulator.propagate();
      notifyListeners();
    }
  }

  void pressUpAll() {
    var changed = false;
    for (final c in circuit.components) {
      if (c.type == ComponentType.button && c.state == LogicValue.one) {
        c.state = LogicValue.zero;
        changed = true;
      }
    }
    if (changed) {
      simulator.propagate();
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ Clock

  void setClockRunning(bool running) {
    clockRunning = running;
    _clockTimer?.cancel();
    _clockTimer = null;
    if (running) {
      _clockTimer = Timer.periodic(
        Duration(milliseconds: (1000 / clockHz).round()),
        (_) {
          if (simulator.hasClock) {
            simulator.tickClocks();
            notifyListeners();
          }
        },
      );
    }
    notifyListeners();
  }

  void setClockHz(double hz) {
    clockHz = hz.clamp(0.5, 30.0).toDouble();
    if (clockRunning) setClockRunning(true); // reinicia o timer
    notifyListeners();
  }

  void tickOnce() {
    simulator.tickClocks();
    notifyListeners();
  }

  // ------------------------------------------------------------ Projeto

  void loadCircuit(Circuit c, {String? fileName}) {
    _clockTimer?.cancel();
    clockRunning = false;
    circuit = c;
    simulator = Simulator(circuit);
    clearSelection();
    pendingType = null;
    mode = EditorMode.interact;
    currentFileName = fileName;
    dirty = false;
    _undoStack.clear();
    notifyListeners();
  }

  void newCircuit() => loadCircuit(Circuit());

  void markSaved(String fileName) {
    currentFileName = fileName;
    dirty = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }
}
