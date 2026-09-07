import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/circ_format.dart';
import '../core/circuit.dart';
import '../core/serialization.dart';

/// Um projeto salvo no armazenamento interno do app.
class SavedProject {
  final String name;
  final File file;
  final DateTime modified;
  SavedProject(this.name, this.file, this.modified);
}

/// Salva projetos na pasta de documentos do app e importa/exporta arquivos
/// .circ e .json pelo seletor de arquivos do sistema.
class ProjectStorage {
  Future<Directory> _projectsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/projetos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _sanitize(String name) {
    final clean = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return clean.isEmpty ? 'circuito' : clean;
  }

  Future<List<SavedProject>> listProjects() async {
    final dir = await _projectsDir();
    final result = <SavedProject>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final stat = await entity.stat();
        final base = entity.uri.pathSegments.last;
        result.add(SavedProject(
          base.substring(0, base.length - 5),
          entity,
          stat.modified,
        ));
      }
    }
    result.sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  Future<String> save(Circuit circuit, String name) async {
    final dir = await _projectsDir();
    final safe = _sanitize(name);
    final file = File('${dir.path}/$safe.json');
    circuit.name = safe;
    await file.writeAsString(CircuitJson.encode(circuit));
    return safe;
  }

  Future<Circuit> load(File file) async =>
      CircuitJson.decode(await file.readAsString());

  Future<void> delete(SavedProject p) => p.file.delete();

  /// Abre o seletor de arquivos e importa um .circ (Logisim) ou .json (deste
  /// app). Retorna null se o usuário cancelar.
  Future<CircImportResult?> pickAndImport() async {
    final f = await FilePicker.pickFile(type: FileType.any);
    if (f == null) return null;
    final content = utf8.decode(await f.readAsBytes(), allowMalformed: true);
    final lower = f.name.toLowerCase();
    if (lower.endsWith('.json')) {
      return CircImportResult(CircuitJson.decode(content), const []);
    }
    // .circ (ou qualquer XML do Logisim)
    return CircFormat.import(content);
  }

    /// Exporta como .circ e abre a folha de compartilhamento do sistema.
  Future<void> exportCirc(Circuit circuit, String name) async {
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/${_sanitize(name)}.circ');
    await file.writeAsString(CircFormat.export(circuit));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/xml')],
      text: 'Circuito exportado do Logisim Mobile',
    ));
  }

  /// Exporta o JSON do projeto pela folha de compartilhamento.
  Future<void> exportJson(Circuit circuit, String name) async {
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/${_sanitize(name)}.json');
    await file.writeAsString(CircuitJson.encode(circuit));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
    ));
  }
}
