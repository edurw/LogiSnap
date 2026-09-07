# LogiSnap — estado do projeto (23/08/2026)
 
App Flutter (Android) inspirado no Logisim Evolution, entregue como `logisnap.zip` na conversa.
 
## O que existe
- MVP funcional: canvas com pan/zoom por toque, paleta com 14 componentes (pinos de entrada/saída, LED, botão, clock, constante, NOT, Buffer, AND, OR, NAND, NOR, XOR, XNOR — 1 bit, 2 a 8 entradas), modos Interagir/Mover/Fio/Apagar, girar/rótulo/duplicar, undo.
- Motor de simulação por ponto fixo com semântica do Logisim: entradas flutuantes ignoradas, cruzamento de fios não conecta (junção em T conecta), conflito de drivers = erro, latch SR converge, oscilação detectada.
- Persistência: projetos JSON internos (salvar/abrir/apagar), importação e exportação de `.circ` do Logisim Evolution (mesma geometria de grade — fios encaixam), 3 exemplos embutidos (meia-somadora, latch SR, pisca-pisca com clock).
- Testes: `flutter test` cobre motor, netlist, importador/exportador .circ e JSON. A lógica foi validada por espelho em Python nesta sessão (23/23 casos).
## Decisões técnicas
- Geometria idêntica à do Logisim (grade de 10, âncora = pino de saída, offsets de entradas com "pular o centro" para nº par; NAND/NOR/XOR axis +10, XNOR +20, NOT 30, Buffer 20). Gates sem atributo `inputs` no .circ = 5 entradas.
- Sem código do Logisim Evolution (GPL); apenas o formato .circ é suportado.
- Sem Flutter SDK no ambiente da sessão — código revisado por agente; 2 erros de compilação corrigidos (shouldRepaint ausente; clamp num→double). Não foi compilado de fato ainda.
## Próximos passos possíveis
- Flip-flops/registradores, barramentos multi-bit e splitters, subcircuitos, display de 7 segmentos, exportar imagem do circuito, redo, seleção múltipla.