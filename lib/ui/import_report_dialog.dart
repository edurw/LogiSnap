import 'package:flutter/material.dart';

import '../core/circ_format.dart';

/// Conta ao usuário o que a importação de um `.circ` deixou de fora.
///
/// O caso comum é o arquivo trazer componentes que o app ainda não tem
/// (flip-flops, memórias…): o resto entra normalmente e os fios que chegavam
/// neles ficam com as pontas em aberto.
class ImportReportDialog extends StatelessWidget {
  final CircImportResult result;

  const ImportReportDialog(this.result, {super.key});

  @override
  Widget build(BuildContext context) {
    final omitidos = result.omittedLabels;
    final avisos = result.warnings;

    return AlertDialog(
      title: Text(omitidos.isEmpty
          ? 'Avisos da importação'
          : 'Alguns componentes não foram importados'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (omitidos.isNotEmpty) ...[
              const Text(
                'O LogiSnap ainda não tem estes componentes, então eles '
                'ficaram de fora. O resto do circuito foi importado '
                'normalmente, e os fios que chegavam neles continuam no '
                'lugar, com as pontas em aberto:',
              ),
              const SizedBox(height: 12),
              for (final o in omitidos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('•  $o'),
                ),
            ],
            if (avisos.isNotEmpty) ...[
              if (omitidos.isNotEmpty) const Divider(height: 24),
              for (final a in avisos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('•  $a'),
                ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}

/// Mostra o relatório da importação — e não faz nada quando não há o que
/// contar, para uma importação limpa não interromper o usuário.
Future<void> showImportReport(
  BuildContext context,
  CircImportResult result,
) {
  if (result.omitted.isEmpty && result.warnings.isEmpty) {
    return Future<void>.value();
  }
  return showDialog<void>(
    context: context,
    builder: (context) => ImportReportDialog(result),
  );
}
