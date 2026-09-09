import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/circ_format.dart';
import '../core/component.dart';
import '../state/editor_state.dart';
import 'circuit_canvas.dart';
import 'project_storage.dart';
import 'projects_screen.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final EditorState st = EditorState();
  final ProjectStorage storage = ProjectStorage();

  @override
  void dispose() {
    st.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: st,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            (st.currentFileName ?? 'Sem título') + (st.dirty ? ' •' : ''),
            style: const TextStyle(fontSize: 17),
          ),
          actions: [
            if (st.canUndo)
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Desfazer',
                onPressed: st.undo,
              ),
            if (st.simulator.hasClock)
              IconButton(
                icon: Icon(st.clockRunning ? Icons.pause : Icons.play_arrow),
                tooltip: st.clockRunning ? 'Pausar clock' : 'Rodar clock',
                onPressed: () => st.setClockRunning(!st.clockRunning),
              ),
            PopupMenuButton<String>(
              onSelected: _onMenu,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'new', child: Text('Novo circuito')),
                PopupMenuItem(value: 'open', child: Text('Meus projetos')),
                PopupMenuItem(value: 'save', child: Text('Salvar')),
                PopupMenuItem(value: 'saveAs', child: Text('Salvar como…')),
                PopupMenuDivider(),
                PopupMenuItem(
                    value: 'import', child: Text('Importar (.circ / .json)')),
                PopupMenuItem(value: 'exportCirc', child: Text('Exportar .circ')),
                PopupMenuItem(value: 'exportJson', child: Text('Exportar .json')),
                PopupMenuDivider(),
                PopupMenuItem(value: 'examples', child: Text('Exemplos')),
                PopupMenuItem(value: 'clock', child: Text('Velocidade do clock…')),
                PopupMenuItem(value: 'about', child: Text('Sobre')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (st.simulator.oscillating)
              Container(
                width: double.infinity,
                color: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                child: const Text(
                  'O circuito está oscilando!',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  CircuitCanvas(state: st),
                  if (st.mode == EditorMode.place && st.pendingType != null)
                    _hintBar(
                        'Toque no canvas para adicionar: '
                        '${st.pendingType!.displayName}'),
                  if (st.mode == EditorMode.wire)
                    _hintBar(st.linkAnchor == null
                        ? 'Toque em um componente para começar a ligação '
                            '(ou arraste para desenhar o fio à mão)'
                        : 'Agora toque no componente de destino — '
                            'toque no vazio para cancelar'),
                  if (st.mode == EditorMode.erase)
                    _hintBar('Toque em um componente ou fio para apagar '
                        '(o fio sai inteiro)'),
                  if (st.mode == EditorMode.select && st.selected != null)
                    _selectionBar(context),
                  if (st.mode == EditorMode.select && st.selectedWire != null)
                    _wireSelectionBar(context),
                ],
              ),
            ),
            _palette(context),
            _toolbar(context),
          ],
        ),
      ),
    );
  }

  Widget _hintBar(String text) => Positioned(
        top: 8,
        left: 8,
        right: 8,
        child: Card(
          color: Colors.blueGrey.shade50,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Text(text, textAlign: TextAlign.center),
          ),
        ),
      );

  // ------------------------------------------------------ Barra de seleção

  Widget _selectionBar(BuildContext context) {
    final c = st.selected!;
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  c.label.isEmpty ? c.type.displayName : '${c.type.displayName} "${c.label}"',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.rotate_right),
                tooltip: 'Girar',
                onPressed: st.rotateSelected,
              ),
              if (c.type.isMultiInputGate)
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Nº de entradas',
                  onPressed: () => _askInputs(c),
                ),
              IconButton(
                icon: const Icon(Icons.label_outline),
                tooltip: 'Rótulo',
                onPressed: () => _askLabel(c),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Duplicar',
                onPressed: st.duplicateSelected,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Apagar',
                onPressed: st.deleteSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra do fio selecionado, em dois estados: selecionado (ações no fio
  /// inteiro) e em edição (moldando o traçado pelas alças).
  Widget _wireSelectionBar(BuildContext context) {
    final w = st.selectedWire!;
    final editing = st.editingWire;
    final trechos =
        w.segmentCount == 1 ? '1 trecho' : '${w.segmentCount} trechos';
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Card(
        color: editing ? Theme.of(context).colorScheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  editing
                      ? 'Editando — arraste as alças do fio'
                      : 'Fio — $trechos · arraste para mover',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (editing)
                FilledButton.icon(
                  onPressed: st.endWireEdit,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Concluir'),
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar o traçado',
                  onPressed: st.startWireEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Duplicar',
                  onPressed: st.duplicateSelected,
                ),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Apagar o fio inteiro',
                onPressed: st.deleteSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _askInputs(Component c) async {
    final n = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Número de entradas'),
        children: [
          for (var i = 2; i <= 8; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text('$i entradas'),
            ),
        ],
      ),
    );
    if (n != null) st.setSelectedInputs(n);
  }

  Future<void> _askLabel(Component c) async {
    final controller = TextEditingController(text: c.label);
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rótulo do componente'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (label != null) st.setSelectedLabel(label.trim());
  }

  // ------------------------------------------------------ Paleta

  /// Tipos oferecidos na paleta.
  ///
  /// LED, botão, clock e constante continuam existindo no núcleo (para abrir
  /// arquivos .circ e projetos antigos que os usem), mas não são mais
  /// oferecidos para adicionar.
  static const List<ComponentType> _paletteTypes = [
    ComponentType.inputPin,
    ComponentType.outputPin,
    ComponentType.notGate,
    ComponentType.bufferGate,
    ComponentType.andGate,
    ComponentType.orGate,
    ComponentType.nandGate,
    ComponentType.norGate,
    ComponentType.xorGate,
    ComponentType.xnorGate,
  ];

  Widget _palette(BuildContext context) {
    return Container(
      height: 52,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        itemCount: _paletteTypes.length,
        itemBuilder: (context, i) {
          final type = _paletteTypes[i];
          final selected =
              st.mode == EditorMode.place && st.pendingType == type;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ChoiceChip(
              label: Text(type.displayName),
              selected: selected,
              onSelected: (_) => st.choosePaletteType(type),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------ Barra de modos

  Widget _toolbar(BuildContext context) {
    Widget button(EditorMode mode, IconData icon, String label) {
      final active = st.mode == mode;
      return Expanded(
        child: InkWell(
          onTap: () => st.setMode(mode),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: active
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22),
                Text(label, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: const Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          children: [
            button(EditorMode.interact, Icons.touch_app, 'Interagir'),
            button(EditorMode.select, Icons.open_with, 'Mover'),
            button(EditorMode.wire, Icons.timeline, 'Fio'),
            button(EditorMode.erase, Icons.backspace_outlined, 'Apagar'),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------ Menu

  Future<void> _onMenu(String action) async {
    switch (action) {
      case 'new':
        if (await _confirmDiscard()) st.newCircuit();
        break;
      case 'open':
        if (!await _confirmDiscard()) return;
        if (!mounted) return;
        final opened = await Navigator.push<Object?>(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectsScreen(storage: storage),
          ),
        );
        if (opened is SavedProject) {
          try {
            final circuit = await storage.load(opened.file);
            st.loadCircuit(circuit, fileName: opened.name);
          } catch (e) {
            _toast('Erro ao abrir: $e');
          }
        }
        break;
      case 'save':
        await _save(askName: st.currentFileName == null);
        break;
      case 'saveAs':
        await _save(askName: true);
        break;
      case 'import':
        if (!await _confirmDiscard()) return;
        try {
          final result = await storage.pickAndImport();
          if (result == null) return;
          st.loadCircuit(result.circuit, fileName: result.circuit.name);
          st.dirty = true;
          if (result.warnings.isNotEmpty) _showWarnings(result.warnings);
        } catch (e) {
          _toast('Falha na importação: $e');
        }
        break;
      case 'exportCirc':
        try {
          await storage.exportCirc(
              st.circuit, st.currentFileName ?? 'circuito');
        } catch (e) {
          _toast('Falha na exportação: $e');
        }
        break;
      case 'exportJson':
        try {
          await storage.exportJson(
              st.circuit, st.currentFileName ?? 'circuito');
        } catch (e) {
          _toast('Falha na exportação: $e');
        }
        break;
      case 'examples':
        if (await _confirmDiscard()) _showExamples();
        break;
      case 'clock':
        _askClockSpeed();
        break;
      case 'about':
        _showAbout();
        break;
    }
  }

  Future<void> _save({required bool askName}) async {
    var name = st.currentFileName;
    if (askName || name == null) {
      final controller = TextEditingController(text: name ?? 'meu-circuito');
      name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nome do projeto'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty) return;
    }
    try {
      final saved = await storage.save(st.circuit, name);
      st.markSaved(saved);
      _toast('Projeto salvo.');
    } catch (e) {
      _toast('Erro ao salvar: $e');
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!st.dirty) return true;
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text(
            'O circuito atual tem alterações não salvas. Deseja continuar '
            'mesmo assim?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  void _showWarnings(List<String> warnings) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avisos da importação'),
        content: SingleChildScrollView(
          child: Text(warnings.map((w) => '• $w').join('\n\n')),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static const _examples = {
    'Meia-somadora': 'assets/examples/meia_somadora.circ',
    'Latch SR (NOR)': 'assets/examples/latch_sr.circ',
    'Pisca-pisca com clock': 'assets/examples/pisca_clock.circ',
  };

  Future<void> _showExamples() async {
    final path = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Exemplos'),
        children: [
          for (final e in _examples.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, e.value),
              child: Text(e.key),
            ),
        ],
      ),
    );
    if (path == null) return;
    try {
      final xml = await rootBundle.loadString(path);
      final result = CircFormat.import(xml);
      st.loadCircuit(result.circuit,
          fileName: path.split('/').last.replaceAll('.circ', ''));
      if (result.warnings.isNotEmpty) _showWarnings(result.warnings);
    } catch (e) {
      _toast('Erro ao carregar exemplo: $e');
    }
  }

  Future<void> _askClockSpeed() async {
    var hz = st.clockHz;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Velocidade do clock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${hz.toStringAsFixed(1)} alternâncias por segundo'),
              Slider(
                min: 0.5,
                max: 30,
                value: hz,
                onChanged: (v) => setDialogState(() => hz = v),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                st.setClockHz(hz);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'LogiSnap',
      applicationVersion: '0.1.1',
      children: const [
        Text('Simulador de circuitos lógicos digitais para celular, '
            'inspirado no Logisim Evolution.\n\n'
            'Compatível com arquivos .circ (componentes básicos, 1 bit).'),
      ],
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
