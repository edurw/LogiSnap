# LogiSnap

Simulador de circuitos lógicos digitais para Android, feito em Flutter e
inspirado no [Logisim Evolution](https://github.com/logisim-evolution/logisim-evolution).

## Recursos (MVP)

- **Canvas com toque**: pan com um dedo, zoom com dois dedos, grade no estilo Logisim.
- **Componentes**: Entrada, Saída, LED, Botão, Clock, Constante, NOT, Buffer,
  AND, OR, NAND, NOR, XOR, XNOR (1 bit, 2–8 entradas nas portas).
- **Simulação em tempo real**: os fios mudam de cor conforme o valor
  (verde-claro = 1, verde-escuro = 0, azul = flutuante, vermelho = erro/conflito),
  com detecção de oscilação e clock com velocidade ajustável.
- **Modos de edição**: Interagir (poke), Mover/selecionar (com girar, rótulo,
  nº de entradas, duplicar), Fio (arraste com roteamento em L) e Apagar.
- **Projetos**: salvar/abrir no dispositivo (JSON) e desfazer (undo).
- **Compatibilidade .circ**: importa e exporta arquivos do Logisim
  Evolution (componentes suportados, 1 bit). A geometria segue a do Logisim,
  então os fios dos arquivos importados encaixam nos mesmos pontos.
- **Exemplos embutidos**: meia-somadora, latch SR e pisca-pisca com clock
  (menu ⋮ → Exemplos).

## Como compilar

Pré-requisitos: [Flutter](https://docs.flutter.dev/get-started/install) 3.22+
com toolchain Android configurada (`flutter doctor`).

```bash
cd logisnap
flutter pub get
flutter run            # com um celular/emulador conectado
flutter build apk      # gera build/app/outputs/flutter-apk/app-release.apk
```

Para rodar os testes (motor de simulação, importador .circ, JSON):

```bash
flutter test
```

Se a sua versão do Flutter reclamar de versões do Gradle/AGP, regenere a
pasta Android mantendo o código Dart:

```bash
rm -rf android
flutter create --platforms=android --org dev.chico --project-name logisnap .
```

## Estrutura do código

```
lib/
  core/            # lógica pura (sem Flutter) — testável isoladamente
    values.dart        # valores lógicos (0, 1, flutuante, erro)
    geometry.dart      # grade, pontos, rotação (convenções do Logisim)
    component.dart     # tipos de componente, portas e funções lógicas
    wire.dart          # segmentos de fio
    circuit.dart       # circuito + construção da netlist (union-find)
    simulator.dart     # propagação até ponto fixo + detecção de oscilação
    serialization.dart # formato JSON do app
    circ_format.dart   # importador/exportador .circ (Logisim)
  state/
    editor_state.dart  # estado do editor (modos, undo, clock, seleção)
  ui/
    editor_screen.dart # tela principal, menus, paleta, barra de modos
    circuit_canvas.dart# gestos de toque e viewport
    circuit_painter.dart# desenho dos componentes no estilo Logisim
    project_storage.dart# salvar/abrir/importar/exportar
    projects_screen.dart# lista de projetos salvos
test/                # testes de unidade do motor e dos formatos
assets/examples/     # circuitos .circ de exemplo
```

## Semântica da simulação

Segue o Logisim no que importa para circuitos básicos: entradas de porta
flutuantes são ignoradas quando há outras conectadas (portas importadas com 5
entradas e só 2 ligadas funcionam); fios que apenas se cruzam **não** se
conectam, mas um fio que termina sobre outro conecta (junção); dois drivers
em conflito produzem erro (vermelho); realimentações estáveis (latch SR)
convergem e realimentações instáveis são sinalizadas como oscilação.

## Limitações desta versão

- Apenas 1 bit por fio (sem barramentos/splitters), sem subcircuitos,
  sem flip-flops/memória prontos (dá para montar um latch com portas).
- Importação .circ ignora componentes não suportados, listando avisos.

## Licença

Código novo, sem reutilizar código-fonte do Logisim Evolution (GPL-3.0).
O formato de arquivo .circ é suportado para interoperabilidade.
