import 'package:flutter/material.dart';

import '../../models/vault_file.dart';
import '../../models/vault_folder.dart';
import '../../services/vault_repository.dart';

sealed class GlobalSearchPick {
  const GlobalSearchPick();
}

class PickFolder extends GlobalSearchPick {
  const PickFolder(this.folderId);
  final int folderId;
}

class PickFile extends GlobalSearchPick {
  const PickFile(this.file);
  final VaultFile file;
}

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key, required this.repo});

  final VaultRepository repo;

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  List<VaultFolder> _folders = [];
  List<VaultFile> _files = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _folders = [];
        _files = [];
      });
      return;
    }

    setState(() => _busy = true);
    try {
      final folders = await widget.repo.searchFolders(q, limit: 40);
      final files = await widget.repo.searchFiles(q, limit: 60);
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _files = files;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search vault'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search folders and files',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Clear',
                  onPressed: () {
                    _controller.clear();
                    _run();
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
              onChanged: (_) => _run(),
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              children: [
                if (_folders.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text('Folders'),
                  ),
                  ..._folders.map(
                    (f) => ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(f.name),
                      subtitle: const Text('Tap to open'),
                      onTap: () => Navigator.pop(context, PickFolder(f.id)),
                    ),
                  ),
                ],
                if (_files.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text('Files'),
                  ),
                  ..._files.map(
                    (file) => ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(file.originalName),
                      subtitle: const Text('Tap to open location'),
                      onTap: () => Navigator.pop(context, PickFile(file)),
                    ),
                  ),
                ],
                if (!_busy && _folders.isEmpty && _files.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Type to search your vault.'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

