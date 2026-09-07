import 'package:flutter/material.dart';

import 'project_storage.dart';

/// Lista de projetos salvos no dispositivo.
class ProjectsScreen extends StatefulWidget {
  final ProjectStorage storage;
  const ProjectsScreen({super.key, required this.storage});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late Future<List<SavedProject>> _future = widget.storage.listProjects();

  void _reload() {
    setState(() => _future = widget.storage.listProjects());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus projetos')),
      body: FutureBuilder<List<SavedProject>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final projects = snapshot.data!;
          if (projects.isEmpty) {
            return const Center(
              child: Text('Nenhum projeto salvo ainda.\n'
                  'Use "Salvar como…" no editor.'),
            );
          }
          return ListView.separated(
            itemCount: projects.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = projects[i];
              return ListTile(
                leading: const Icon(Icons.memory),
                title: Text(p.name),
                subtitle: Text(
                  'Modificado em ${_format(p.modified)}',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => Navigator.pop(context, p),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Apagar "${p.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Apagar'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await widget.storage.delete(p);
                      _reload();
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}'
      '/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
