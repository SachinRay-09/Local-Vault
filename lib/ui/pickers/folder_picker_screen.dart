import 'package:flutter/material.dart';

import '../../models/vault_folder.dart';
import '../../services/vault_repository.dart';

class FolderPickerScreen extends StatefulWidget {
  const FolderPickerScreen({
    super.key,
    required this.repo,
    this.title = 'Select destination',
  });

  final VaultRepository repo;
  final String title;

  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen> {
  int? _currentFolderId;
  final List<VaultFolder> _stack = [];
  bool _loading = true;
  List<VaultFolder> _folders = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final folders = await widget.repo.listFolders(parentId: _currentFolderId);
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _loading = false;
    });
  }

  Future<bool> _pop() async {
    if (_stack.isEmpty) return true;
    setState(() {
      _stack.removeLast();
      _currentFolderId = _stack.isEmpty ? null : _stack.last.id;
    });
    await _refresh();
    return false;
  }

  void _open(VaultFolder folder) {
    setState(() {
      _stack.add(folder);
      _currentFolderId = folder.id;
    });
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stack.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _stack.isEmpty
              ? null
              : IconButton(onPressed: _pop, icon: const Icon(Icons.arrow_back)),
          title: Text(_stack.isEmpty ? widget.title : _stack.last.name),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop<int?>(context, _currentFolderId),
              child: const Text('Pick'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: const Text('Root'),
                    subtitle: const Text('Move here'),
                    onTap: () => Navigator.pop<int?>(context, null),
                  ),
                  const Divider(height: 1),
                  ..._folders.map(
                    (f) => ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(f.name),
                      onTap: () => _open(f),
                    ),
                  ),
                  if (_folders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No folders here.'),
                    ),
                ],
              ),
      ),
    );
  }
}

