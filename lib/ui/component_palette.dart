import 'package:flutter/material.dart';

import '../core/component.dart';
import '../state/editor_state.dart';
import 'component_icon.dart';

/// Uma aba da paleta: nome exibido e os componentes que ela oferece.
class PaletteCategory {
  final String name;
  final List<ComponentType> types;

  const PaletteCategory(this.name, this.types);
}

/// Categorias da paleta — a única fonte de verdade do que ela oferece.
///
/// Para oferecer um componente novo, basta incluí-lo na lista da categoria
/// dele. Categorias sem componentes ficam declaradas aqui (o lugar delas já
/// está reservado), mas não aparecem na barra enquanto estiverem vazias.
const List<PaletteCategory> kPaletteCategories = [
  PaletteCategory('E/S', [
    ComponentType.inputPin,
    ComponentType.outputPin,
    ComponentType.led,
    ComponentType.button,
    ComponentType.clock,
    ComponentType.constant,
  ]),
  PaletteCategory('Portas', [
    ComponentType.andGate,
    ComponentType.nandGate,
    ComponentType.orGate,
    ComponentType.norGate,
    ComponentType.xorGate,
    ComponentType.xnorGate,
    ComponentType.bufferGate,
    ComponentType.notGate,
  ]),
  PaletteCategory('Sequencial', []),
  PaletteCategory('Fiação', []),
];

/// Categorias que têm o que mostrar.
List<PaletteCategory> get visiblePaletteCategories =>
    [for (final c in kPaletteCategories) if (c.types.isNotEmpty) c];

/// Todos os tipos oferecidos na paleta, em ordem.
List<ComponentType> get paletteTypes =>
    [for (final c in kPaletteCategories) ...c.types];

/// Paleta em duas fileiras: categorias em cima, componentes da categoria
/// escolhida embaixo.
class ComponentPalette extends StatefulWidget {
  final EditorState state;

  const ComponentPalette({super.key, required this.state});

  @override
  State<ComponentPalette> createState() => _ComponentPaletteState();
}

class _ComponentPaletteState extends State<ComponentPalette> {
  /// Altura da fileira de categorias: o chip tem 32 de desenho, mas o alvo
  /// de toque continua com os 48 do Material.
  static const double _categoriesHeight = 48;
  static const double _componentsHeight = 52;

  int _category = 0;
  final ScrollController _componentsScroll = ScrollController();

  @override
  void dispose() {
    _componentsScroll.dispose();
    super.dispose();
  }

  void _pickCategory(int index) {
    if (index == _category) return;
    setState(() => _category = index);
    // Categoria nova começa do começo, senão a fileira abre no meio da
    // rolagem que sobrou da anterior.
    if (_componentsScroll.hasClients) _componentsScroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = visiblePaletteCategories;
    final types = categories[_category].types;

    return Container(
      color: scheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _categoriesHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              itemCount: categories.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Center(child: _categoryChip(scheme, categories[i], i)),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          SizedBox(
            height: _componentsHeight,
            child: ListView.builder(
              controller: _componentsScroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              itemCount: types.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Center(child: _componentChip(types[i])),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(ColorScheme scheme, PaletteCategory category, int i) {
    final selected = i == _category;
    return FilterChip(
      label: Text(category.name),
      selected: selected,
      onSelected: (_) => _pickCategory(i),
      selectedColor: scheme.primaryContainer,
      backgroundColor: Colors.transparent,
      side: selected ? BorderSide.none : BorderSide(color: scheme.outline),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      // 32 dp de desenho; o alvo de toque continua nos 48 dp que o chip
      // reserva em volta (a densidade compacta encolheria os dois).
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  Widget _componentChip(ComponentType type) {
    final st = widget.state;
    final selected = st.mode == EditorMode.place && st.pendingType == type;
    return Tooltip(
      message: type.displayName,
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ComponentIcon(type),
            const SizedBox(width: 6),
            Text(type.displayName),
          ],
        ),
        selected: selected,
        onSelected: (_) => st.choosePaletteType(type),
      ),
    );
  }
}
