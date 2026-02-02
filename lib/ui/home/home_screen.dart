import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import '../../models/vault_file.dart';
import '../../models/vault_folder.dart';
import '../../services/bulk_import_service.dart';
import '../../services/file_crypto_service.dart';
import '../../services/file_open_service.dart';
import '../../services/import_export_service.dart';
import '../../services/secure_storage_service.dart';
import '../../services/undo_service.dart';
import '../../services/vault_open_service.dart';
import '../../services/vault_repository.dart';
import '../../services/yomikiru_integration_service.dart';
import '../../utils/vault_format.dart';
import '../auth/auth_gate.dart';
import '../pickers/folder_picker_screen.dart';
import '../settings/settings_screen.dart';
import '../search/global_search_screen.dart';
import '../viewers/video_viewer_screen.dart';
import '../widgets/optimized_image_viewer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VaultRepository _repo = VaultRepository(
    crypto: const FileCryptoService(),
    secureStorage: SecureStorageService.instance,
  );

  late final VaultOpenService _openService = VaultOpenService(
    crypto: const FileCryptoService(),
    secureStorage: SecureStorageService.instance,
    opener: FileOpenService(),
  );

  bool _gridView = false;

  late final ImportExportService _importExport = ImportExportService(
    repo: _repo,
    crypto: const FileCryptoService(),
    secureStorage: SecureStorageService.instance,
  );

  late final BulkImportService _bulkImport = BulkImportService(
    repo: _repo,
    crypto: const FileCryptoService(),
    secureStorage: SecureStorageService.instance,
  );

  late final YomikiruIntegrationService _yomikiru = YomikiruIntegrationService(
    repo: _repo,
    openService: _openService,
  );

  final UndoService _undoService = UndoService();

  int? _currentFolderId;
  final List<VaultFolder> _folderStack = [];

  bool _loading = true;
  List<VaultFolder> _folders = [];
  List<VaultFile> _files = [];
  String _query = '';

  // Pagination
  static const int _pageSize = 50;
  int _currentPage = 0;
  bool _hasMoreFiles = true;
  bool _loadingMore = false;
  int _totalFileCount = 0;

  // Sort state (simple, per-current-view)
  String _sort = 'name'; // name | date | size
  bool _sortAsc = true;

  // Multi-select state
  bool _multiSelectMode = false;
  final Set<int> _selectedFileIds = {};
  final Set<int> _selectedFolderIds = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _currentPage = 0;
      _files.clear();
      _hasMoreFiles = true;
      // Clear selections when refreshing
      _multiSelectMode = false;
      _selectedFileIds.clear();
      _selectedFolderIds.clear();
    });
    
    final folders = await _repo.listFolders(parentId: _currentFolderId);
    final totalCount = await _repo.countFiles(parentId: _currentFolderId);
    final files = await _repo.listFiles(
      parentId: _currentFolderId,
      limit: _pageSize,
      offset: 0,
    );
    
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _files = files;
      _totalFileCount = totalCount;
      _hasMoreFiles = files.length >= _pageSize && files.length < totalCount;
      _loading = false;
    });
  }

  Future<void> _loadMoreFiles() async {
    if (_loadingMore || !_hasMoreFiles) return;
    
    setState(() => _loadingMore = true);
    
    final nextPage = _currentPage + 1;
    final moreFiles = await _repo.listFiles(
      parentId: _currentFolderId,
      limit: _pageSize,
      offset: nextPage * _pageSize,
    );
    
    if (!mounted) return;
    setState(() {
      _files.addAll(moreFiles);
      _currentPage = nextPage;
      _hasMoreFiles = moreFiles.length >= _pageSize && _files.length < _totalFileCount;
      _loadingMore = false;
    });
  }

  Widget _breadcrumbs() {
    final segments = <Widget>[
      TextButton(
        onPressed: () {
          setState(() {
            _folderStack.clear();
            _currentFolderId = null;
          });
          _refresh();
        },
        child: const Text('Root'),
      ),
    ];

    for (var i = 0; i < _folderStack.length; i++) {
      final f = _folderStack[i];
      segments.add(const Text(' / '));
      segments.add(
        TextButton(
          onPressed: () {
            setState(() {
              _folderStack.removeRange(i + 1, _folderStack.length);
              _currentFolderId = _folderStack.isEmpty ? null : _folderStack.last.id;
            });
            _refresh();
          },
          child: Text(f.name),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: segments),
    );
  }

  List<VaultFolder> get _visibleFolders {
    final q = _query.trim().toLowerCase();
    var items = _folders;
    if (q.isNotEmpty) {
      items = items.where((f) => f.name.toLowerCase().contains(q)).toList();
    }
    // folders always sort by name (keeps UX predictable)
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!_sortAsc) items = items.reversed.toList();
    return items;
  }

  List<VaultFile> get _visibleFiles {
    final q = _query.trim().toLowerCase();
    var items = _files;
    if (q.isNotEmpty) {
      items = items.where((f) => f.originalName.toLowerCase().contains(q)).toList();
    }

    int cmp(VaultFile a, VaultFile b) {
      switch (_sort) {
        case 'date':
          return a.createdAt.compareTo(b.createdAt);
        case 'size':
          return a.byteSize.compareTo(b.byteSize);
        case 'name':
        default:
          return a.originalName.toLowerCase().compareTo(b.originalName.toLowerCase());
      }
    }

    items.sort(cmp);
    if (!_sortAsc) items = items.reversed.toList();
    return items;
  }

  Future<void> _openGlobalSearch() async {
    final pick = await Navigator.of(context).push<GlobalSearchPick>(
      MaterialPageRoute(builder: (_) => GlobalSearchScreen(repo: _repo)),
    );
    if (!mounted || pick == null) return;

    if (pick is PickFolder) {
      final path = await _repo.folderPathToRoot(folderId: pick.folderId);
      if (!mounted) return;
      setState(() {
        _folderStack
          ..clear()
          ..addAll(path);
        _currentFolderId = pick.folderId;
      });
      await _refresh();
      return;
    }

    if (pick is PickFile) {
      final parentId = pick.file.parentFolderId;
      if (parentId != null) {
        final path = await _repo.folderPathToRoot(folderId: parentId);
        if (!mounted) return;
        setState(() {
          _folderStack
            ..clear()
            ..addAll(path);
          _currentFolderId = parentId;
        });
        await _refresh();
      }
    }
  }

  Future<void> _addFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return;

    await _repo.createFolder(name: trimmed, parentId: _currentFolderId);
    await _refresh();
  }

  Future<void> _addMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final f = result.files.single;
    try {
      await _repo.addMedia(
        originalName: f.name,
        parentFolderId: _currentFolderId,
        sourcePath: f.path,
        bytes: f.bytes,
        mimeType: f.extension,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }

    await _refresh();
  }

  Future<void> _exportAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final outPath = await _importExport.pickExportPath();
    if (outPath == null || outPath.trim().isEmpty) return;

    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Exporting...')));

    try {
      final result = await _importExport.exportAllToZip(outputZipPath: outPath);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export complete'),
          content: SelectableText(
            'ZIP saved to:\n${result.zipPath}\n\nPassword (share this):\n${result.password}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result.password));
                Navigator.pop(context);
              },
              child: const Text('Copy password'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importZip() async {
    final messenger = ScaffoldMessenger.of(context);
    final zipPath = await _importExport.pickImportZipPath();
    if (zipPath == null || zipPath.trim().isEmpty) return;
    if (!mounted) return;

    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import vault'),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: 'ZIP password'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    final pw = (password ?? '').trim();
    if (pw.isEmpty) return;

    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Importing...')));

    try {
      final res = await _importExport.importFromZip(
        zipPath: zipPath,
        password: pw,
        destinationFolderId: _currentFolderId,
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Imported ${res.filesImported} files, ${res.foldersCreated} folders')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  void _openFolder(VaultFolder folder) {
    setState(() {
      _folderStack.add(folder);
      _currentFolderId = folder.id;
    });
    _refresh();
  }

  Future<bool> _popFolder() async {
    if (_folderStack.isEmpty) return true;
    setState(() {
      _folderStack.removeLast();
      _currentFolderId = _folderStack.isEmpty ? null : _folderStack.last.id;
    });
    await _refresh();
    return false;
  }

  Future<void> _openFile(VaultFile file) async {
    if (isImageFileName(file.originalName)) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OptimizedImageViewer(
          file: file,
          allFiles: _files, // Pass all files for navigation
        ),
      ));
      return;
    }
    if (isVideoFileName(file.originalName)) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoViewerScreen(file: file)));
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening ${file.originalName}...')));
    try {
      await _openService.decryptToTempAndOpen(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open failed: $e')));
    }
  }

  Future<void> _importFolder() async {
    // Use directory picker (Windows only for now)
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder import is currently only supported on Windows')),
      );
      return;
    }

    try {
      // For now, we'll use a simple dialog to get folder path
      final controller = TextEditingController();
      final folderPath = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the full path to the folder containing images:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: r'C:\Users\YourName\Pictures\Manga\Series1',
                  labelText: 'Folder Path',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (folderPath == null || folderPath.isEmpty) return;

      if (!await Directory(folderPath).exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder does not exist')),
        );
        return;
      }

      if (!mounted) return;
      
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _BulkImportProgressDialog(
          bulkImport: _bulkImport,
          sourceFolderPath: folderPath,
          destinationFolderId: _currentFolderId,
          onComplete: () {
            Navigator.pop(context);
            _refresh();
          },
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  Future<void> _openFolderInYomikiru(VaultFolder folder) async {
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      messenger.showSnackBar(
        SnackBar(content: Text('Preparing "${folder.name}" for Yomikiru...')),
      );

      final result = await _yomikiru.openFolderInYomikiru(folder);
      
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      
      if (result.success) {
        // Yomikiru launched successfully
        _showYomikiruSuccessDialog(folder.name, result.tempFolderPath);
      } else {
        // Yomikiru not found, show path for manual setup
        _showYomikiruNotFoundDialog(result.tempFolderPath, result.error);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to open in Yomikiru: $e')),
      );
    }
  }

  void _showYomikiruSuccessDialog(String folderName, String tempPath) {
    final messenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing without action
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Yomikiru Launched'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Successfully launched Yomikiru with folder "$folderName"!'),
            const SizedBox(height: 16),
            const Text('Images exported to:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      tempPath,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tempPath));
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Path copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy path',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 Tip:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('If images don\'t appear in Yomikiru, copy the path above and set it as the manga folder in Yomikiru\'s settings.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '🔒 Security: Click "Clean Up" when you\'re done reading to remove temp files.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Process.start('explorer', [tempPath], mode: ProcessStartMode.detached);
            },
            child: const Text('Open Folder'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Reading'),
          ),
          FilledButton(
            onPressed: () async {
              // Clean up temp folder
              await _yomikiru.cleanupTempFolder(tempPath);
              if (mounted) {
                Navigator.pop(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Temp folder cleaned up successfully!')),
                );
              }
            },
            child: const Text('Clean Up'),
          ),
        ],
      ),
    );
  }

  void _showYomikiruNotFoundDialog(String tempPath, String? error) {
    final messenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing without action
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('Yomikiru Not Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yomikiru was not found, but your images have been exported to:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      tempPath,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tempPath));
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Path copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy path',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📋 Next Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('1. Install Yomikiru at D:\\Yomikiru.exe and try again'),
                  Text('2. Copy the path above and set it in Yomikiru settings'),
                  Text('3. Open the folder manually in your preferred manga reader'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '🔒 Security: Click "Clean Up" when you\'re done reading to remove temp files.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: tempPath));
              messenger.showSnackBar(
                const SnackBar(content: Text('Path copied to clipboard!')),
              );
            },
            child: const Text('Copy Path'),
          ),
          TextButton(
            onPressed: () async {
              await Process.start('explorer', [tempPath], mode: ProcessStartMode.detached);
            },
            child: const Text('Open Folder'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Reading'),
          ),
          FilledButton(
            onPressed: () async {
              // Clean up temp folder
              await _yomikiru.cleanupTempFolder(tempPath);
              if (mounted) {
                Navigator.pop(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Temp folder cleaned up successfully!')),
                );
              }
            },
            child: const Text('Clean Up'),
          ),
        ],
      ),
    );
  }

  void _showFolderContextMenu(BuildContext context, Offset position, VaultFolder folder) {
    // Use showMenu with proper positioning
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
      ),
      items: [
        PopupMenuItem(
          value: 'yomikiru',
          child: const Row(
            children: [
              Icon(Icons.auto_stories, size: 20),
              SizedBox(width: 12),
              Text('Open in Yomikiru'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'move',
          child: const Row(
            children: [
              Icon(Icons.drive_file_move_outline, size: 20),
              SizedBox(width: 12),
              Text('Move'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rename',
          child: const Row(
            children: [
              Icon(Icons.drive_file_rename_outline, size: 20),
              SizedBox(width: 12),
              Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: const Row(
            children: [
              Icon(Icons.delete_outline, size: 20),
              SizedBox(width: 12),
              Text('Delete'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null && mounted) {
        switch (value) {
          case 'yomikiru':
            _openFolderInYomikiru(folder);
            break;
          case 'move':
            _moveFolder(folder);
            break;
          case 'rename':
            _renameFolder(folder);
            break;
          case 'delete':
            _deleteFolder(folder);
            break;
        }
      }
    });
  }

  Future<void> _renameFolder(VaultFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return;
    await _repo.renameFolder(folderId: folder.id, newName: trimmed);
    await _refresh();
  }

  Future<void> _deleteFolder(VaultFolder folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete folder?'),
        content: const Text('This deletes the folder and everything inside it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteFolderRecursive(folderId: folder.id);
    await _refresh();
  }

  Future<void> _moveFolder(VaultFolder folder) async {
    final dest = await Navigator.of(context).push<int?>(
      MaterialPageRoute(builder: (_) => FolderPickerScreen(repo: _repo, title: 'Move folder to')),
    );
    if (!mounted) return;
    try {
      await _repo.moveFolder(folderId: folder.id, newParentId: dest);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _renameFile(VaultFile file) async {
    final controller = TextEditingController(text: file.originalName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return;
    await _repo.renameFile(fileId: file.id, newName: trimmed);
    await _refresh();
  }

  Future<void> _deleteFile(VaultFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text(file.originalName),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteFile(fileId: file.id);
    await _refresh();
  }

  Future<void> _moveFile(VaultFile file) async {
    final dest = await Navigator.of(context).push<int?>(
      MaterialPageRoute(builder: (_) => FolderPickerScreen(repo: _repo, title: 'Move file to')),
    );
    if (!mounted) return;
    await _repo.moveFile(fileId: file.id, newParentFolderId: dest);
    await _refresh();
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode) {
        _selectedFileIds.clear();
        _selectedFolderIds.clear();
      }
    });
  }

  void _toggleFileSelection(int fileId) {
    setState(() {
      if (_selectedFileIds.contains(fileId)) {
        _selectedFileIds.remove(fileId);
      } else {
        _selectedFileIds.add(fileId);
      }
    });
  }

  void _toggleFolderSelection(int folderId) {
    setState(() {
      if (_selectedFolderIds.contains(folderId)) {
        _selectedFolderIds.remove(folderId);
      } else {
        _selectedFolderIds.add(folderId);
      }
    });
  }

  Future<void> _deleteSelectedItems() async {
    final selectedFiles = _files.where((f) => _selectedFileIds.contains(f.id)).toList();
    final selectedFolders = _folders.where((f) => _selectedFolderIds.contains(f.id)).toList();
    
    final totalItems = selectedFiles.length + selectedFolders.length;
    if (totalItems == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete selected items?'),
        content: Text('This will delete $totalItems items permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    
    if (ok != true) return;

    // Delete files
    for (final file in selectedFiles) {
      await _repo.deleteFile(fileId: file.id);
    }
    
    // Delete folders
    for (final folder in selectedFolders) {
      await _repo.deleteFolderRecursive(folderId: folder.id);
    }

    setState(() {
      _multiSelectMode = false;
      _selectedFileIds.clear();
      _selectedFolderIds.clear();
    });
    
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _folderStack.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _popFolder();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _folderStack.isEmpty
              ? null
              : IconButton(
                  onPressed: _popFolder,
                  icon: const Icon(Icons.arrow_back),
                ),
          title: _multiSelectMode 
              ? Text('${_selectedFileIds.length + _selectedFolderIds.length} selected')
              : Text(_folderStack.isEmpty ? 'Local Vault' : _folderStack.last.name),
          actions: _multiSelectMode ? [
            if (_selectedFileIds.isNotEmpty || _selectedFolderIds.isNotEmpty)
              IconButton(
                tooltip: 'Delete selected',
                onPressed: _deleteSelectedItems,
                icon: const Icon(Icons.delete),
              ),
            IconButton(
              tooltip: 'Cancel selection',
              onPressed: _toggleMultiSelectMode,
              icon: const Icon(Icons.close),
            ),
          ] : [
            if (_undoService.canUndo)
              IconButton(
                tooltip: 'Undo: ${_undoService.nextUndoDescription}',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await _undoService.undo();
                    await _refresh();
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Undo failed: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.undo),
              ),
            IconButton(
              tooltip: 'Search',
              onPressed: _openGlobalSearch,
              icon: Icon(_query.isEmpty ? Icons.search : Icons.search_off),
            ),
            IconButton(
              tooltip: 'Select multiple',
              onPressed: _toggleMultiSelectMode,
              icon: const Icon(Icons.checklist),
            ),
            IconButton(
              tooltip: 'New folder',
              onPressed: _addFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
            IconButton(
              tooltip: 'Add media',
              onPressed: _addMedia,
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) async {
                if (value == 'import') await _importZip();
                if (value == 'import_folder') await _importFolder();
                if (value == 'export') await _exportAll();
                if (value == 'lock') {
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                    (_) => false,
                  );
                }
                if (value == 'sort_name') setState(() => _sort = 'name');
                if (value == 'sort_date') setState(() => _sort = 'date');
                if (value == 'sort_size') setState(() => _sort = 'size');
                if (value == 'sort_dir') setState(() => _sortAsc = !_sortAsc);
                if (value == 'view_toggle') setState(() => _gridView = !_gridView);
                if (value == 'settings' && context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'import_folder', child: Text('Import Folder')),
                PopupMenuItem(value: 'import', child: Text('Import ZIP')),
                PopupMenuItem(value: 'export', child: Text('Export')),
                PopupMenuDivider(),
                PopupMenuItem(value: 'sort_name', child: Text('Sort: Name')),
                PopupMenuItem(value: 'sort_date', child: Text('Sort: Date')),
                PopupMenuItem(value: 'sort_size', child: Text('Sort: Size')),
                PopupMenuItem(value: 'sort_dir', child: Text('Toggle ascending/descending')),
                PopupMenuItem(value: 'view_toggle', child: Text('Toggle list/grid')),
                PopupMenuDivider(),
                PopupMenuItem(value: 'settings', child: Text('Settings')),
                PopupMenuItem(value: 'lock', child: Text('Lock vault')),
              ],
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: _folderStack.isEmpty ? const SizedBox.shrink() : _breadcrumbs(),
                    ),
                    if (_query.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text('Filter: "$_query"')),
                            TextButton(onPressed: () => setState(() => _query = ''), child: const Text('Clear')),
                          ],
                        ),
                      ),
                    ..._visibleFolders.map(
                      (folder) => GestureDetector(
                        onSecondaryTapDown: (details) {
                          _showFolderContextMenu(context, details.globalPosition, folder);
                        },
                        child: ListTile(
                          leading: _multiSelectMode 
                              ? Checkbox(
                                  value: _selectedFolderIds.contains(folder.id),
                                  onChanged: (_) => _toggleFolderSelection(folder.id),
                                )
                              : const Icon(Icons.folder),
                          title: Text(folder.name),
                          onTap: _multiSelectMode 
                              ? () => _toggleFolderSelection(folder.id)
                              : () => _openFolder(folder),
                          onLongPress: _multiSelectMode ? null : () async {
                            final action = await showModalBottomSheet<String>(
                              context: context,
                              builder: (context) => SafeArea(
                                child: Wrap(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.auto_stories),
                                      title: const Text('Open in Yomikiru'),
                                      onTap: () => Navigator.pop(context, 'yomikiru'),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.drive_file_move_outline),
                                      title: const Text('Move'),
                                      onTap: () => Navigator.pop(context, 'move'),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.drive_file_rename_outline),
                                      title: const Text('Rename'),
                                      onTap: () => Navigator.pop(context, 'rename'),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete_outline),
                                      title: const Text('Delete'),
                                      onTap: () => Navigator.pop(context, 'delete'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (action == 'yomikiru') await _openFolderInYomikiru(folder);
                            if (action == 'move') await _moveFolder(folder);
                            if (action == 'rename') await _renameFolder(folder);
                            if (action == 'delete') await _deleteFolder(folder);
                          },
                        ),
                      ),
                    ),
                    if (!_gridView)
                      ..._visibleFiles.map(
                        (file) => ListTile(
                          leading: _multiSelectMode
                              ? Checkbox(
                                  value: _selectedFileIds.contains(file.id),
                                  onChanged: (_) => _toggleFileSelection(file.id),
                                )
                              : isImageFileName(file.originalName)
                                  ? Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.image,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    )
                                  : const Icon(Icons.insert_drive_file),
                          title: Text(file.originalName),
                          subtitle: Text('${formatBytes(file.byteSize)} • ${formatLocalDateTime(file.createdAt)}'),
                          onTap: _multiSelectMode 
                              ? () => _toggleFileSelection(file.id)
                              : () => _openFile(file),
                          onLongPress: _multiSelectMode ? null : () async {
                          final action = await showModalBottomSheet<String>(
                            context: context,
                            builder: (context) => SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.drive_file_move_outline),
                                    title: const Text('Move'),
                                    onTap: () => Navigator.pop(context, 'move'),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.drive_file_rename_outline),
                                    title: const Text('Rename'),
                                    onTap: () => Navigator.pop(context, 'rename'),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.delete_outline),
                                    title: const Text('Delete'),
                                    onTap: () => Navigator.pop(context, 'delete'),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (action == 'move') await _moveFile(file);
                          if (action == 'rename') await _renameFile(file);
                          if (action == 'delete') await _deleteFile(file);
                        },
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _visibleFiles.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.9,
                          ),
                          itemBuilder: (context, i) {
                            final file = _visibleFiles[i];
                            final isImg = isImageFileName(file.originalName);
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _multiSelectMode 
                                  ? () => _toggleFileSelection(file.id)
                                  : () => _openFile(file),
                              onLongPress: _multiSelectMode ? null : () async {
                                final action = await showModalBottomSheet<String>(
                                  context: context,
                                  builder: (context) => SafeArea(
                                    child: Wrap(
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.drive_file_move_outline),
                                          title: const Text('Move'),
                                          onTap: () => Navigator.pop(context, 'move'),
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.drive_file_rename_outline),
                                          title: const Text('Rename'),
                                          onTap: () => Navigator.pop(context, 'rename'),
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.delete_outline),
                                          title: const Text('Delete'),
                                          onTap: () => Navigator.pop(context, 'delete'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                if (action == 'move') await _moveFile(file);
                                if (action == 'rename') await _renameFile(file);
                                if (action == 'delete') await _deleteFile(file);
                              },
                              child: Stack(
                                children: [
                                  Ink(
                                    decoration: BoxDecoration(
                                      color: _multiSelectMode && _selectedFileIds.contains(file.id)
                                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                                          : Theme.of(context).colorScheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(12),
                                      border: _multiSelectMode && _selectedFileIds.contains(file.id)
                                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                          : null,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Center(
                                              child: isImg
                                                  ? Container(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).colorScheme.primaryContainer,
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Icon(
                                                        Icons.image,
                                                        size: 40,
                                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                      ),
                                                    )
                                                  : const Icon(Icons.insert_drive_file_outlined, size: 40),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            file.originalName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            formatBytes(file.byteSize),
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (_multiSelectMode)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _selectedFileIds.contains(file.id)
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.surface,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                        ),
                                        child: Icon(
                                          _selectedFileIds.contains(file.id)
                                              ? Icons.check
                                              : null,
                                          color: _selectedFileIds.contains(file.id)
                                              ? Theme.of(context).colorScheme.onPrimary
                                              : null,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    if (_visibleFolders.isEmpty && _visibleFiles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No items found.'),
                      ),
                    
                    // Load more button
                    if (_hasMoreFiles && !_loading)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator()
                              : FilledButton.icon(
                                  onPressed: _loadMoreFiles,
                                  icon: const Icon(Icons.expand_more),
                                  label: Text('Load more (${_totalFileCount - _files.length} remaining)'),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}


class _BulkImportProgressDialog extends StatefulWidget {
  const _BulkImportProgressDialog({
    required this.bulkImport,
    required this.sourceFolderPath,
    required this.destinationFolderId,
    required this.onComplete,
  });

  final BulkImportService bulkImport;
  final String sourceFolderPath;
  final int? destinationFolderId;
  final VoidCallback onComplete;

  @override
  State<_BulkImportProgressDialog> createState() => _BulkImportProgressDialogState();
}

class _BulkImportProgressDialogState extends State<_BulkImportProgressDialog> {
  String _currentProgress = 'Starting import...';
  bool _isComplete = false;
  BulkImportResult? _result;

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  Future<void> _startImport() async {
    try {
      final result = await widget.bulkImport.importFolder(
        sourceFolderPath: widget.sourceFolderPath,
        destinationFolderId: widget.destinationFolderId,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _currentProgress = progress);
          }
        },
      );

      if (mounted) {
        setState(() {
          _result = result;
          _isComplete = true;
          _currentProgress = 'Import completed!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isComplete = true;
          _currentProgress = 'Import failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importing Folder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isComplete) const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_currentProgress),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Text('Files imported: ${_result!.filesImported}'),
            Text('Folders created: ${_result!.foldersCreated}'),
            if (_result!.errors.isNotEmpty)
              Text('Errors: ${_result!.errors.length}', style: const TextStyle(color: Colors.orange)),
          ],
        ],
      ),
      actions: [
        if (_isComplete)
          FilledButton(
            onPressed: () {
              widget.onComplete();
            },
            child: const Text('Done'),
          ),
      ],
    );
  }
}