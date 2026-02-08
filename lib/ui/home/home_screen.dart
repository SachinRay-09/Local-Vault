import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import '../../models/vault_file.dart';
import '../../models/vault_folder.dart';
import '../../services/app_lifecycle_service.dart';
import '../../services/bulk_import_service.dart' as bulk;
import '../../services/encrypted_export_service.dart';
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

  late final EncryptedExportService _encryptedExport = EncryptedExportService(
    repo: _repo,
    openService: _openService,
  );

  late final bulk.BulkImportService _bulkImport = bulk.BulkImportService(
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

  @override
  void dispose() {
    // EMERGENCY: Aggressive memory cleanup
    _clearAllCaches();
    _selectedFileIds.clear();
    _selectedFolderIds.clear();
    _files.clear();
    _folders.clear();
    _folderStack.clear();
    super.dispose();
  }

  /// Emergency memory cleanup - clear only image cache, NOT data
  void _clearAllCaches() {
    // Clear image cache immediately to prevent memory buildup
    PaintingBinding.instance.imageCache.clear();
    
    // DO NOT clear _files and _folders here - it breaks the app functionality!
    // Only clear image cache for memory management
  }

  Future<void> _refresh() async {
    debugPrint('DEBUG: Starting refresh for folder $_currentFolderId');
    setState(() {
      _loading = true;
      _currentPage = 0;
      _files.clear();
      _folders.clear();
      _hasMoreFiles = true;
      // Clear selections when refreshing
      _multiSelectMode = false;
      _selectedFileIds.clear();
      _selectedFolderIds.clear();
    });
    
    try {
      final folders = await _repo.listFolders(parentId: _currentFolderId);
      debugPrint('DEBUG: Found ${folders.length} folders');
      final totalCount = await _repo.countFiles(parentId: _currentFolderId);
      debugPrint('DEBUG: Total file count: $totalCount');
      final files = await _repo.listFiles(
        parentId: _currentFolderId,
        limit: _pageSize,
        offset: 0,
      );
      debugPrint('DEBUG: Found ${files.length} files');
      
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _files = files;
        _totalFileCount = totalCount;
        _hasMoreFiles = files.length >= _pageSize && files.length < totalCount;
        _loading = false;
      });
      debugPrint('DEBUG: Refresh completed successfully');
      
      // Only clear image cache after successful data load, not before
      PaintingBinding.instance.imageCache.clear();
    } catch (e) {
      debugPrint('DEBUG: Error during refresh: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
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
    
    // Only clear image cache, not data
    PaintingBinding.instance.imageCache.clear();
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
    // No sorting - preserve original order from database
    // (folders maintain file system order)
    return items;
  }

  List<VaultFile> get _visibleFiles {
    final q = _query.trim().toLowerCase();
    var items = _files;
    if (q.isNotEmpty) {
      items = items.where((f) => f.originalName.toLowerCase().contains(q)).toList();
    }

    // Only sort if user explicitly chose date or size
    // Default 'name' preserves original file system order
    if (_sort == 'date') {
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (!_sortAsc) items = items.reversed.toList();
    } else if (_sort == 'size') {
      items.sort((a, b) => a.byteSize.compareTo(b.byteSize));
      if (!_sortAsc) items = items.reversed.toList();
    }
    // For 'name' or default: preserve original order (no sorting)

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

  /// Quick clear cache from top bar
  Future<void> _clearCacheQuick() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Clearing cache...'),
            ],
          ),
        ),
      );

      // Perform cleanup using the lifecycle service
      final lifecycleService = AppLifecycleService();
      await lifecycleService.performManualCleanup();

      if (!mounted) return;
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared successfully! All temporary files removed.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Close loading dialog if still open
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing cache: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

    try {
      debugPrint('DEBUG: Creating folder "$trimmed" in parent $_currentFolderId');
      final folder = await _repo.createFolder(name: trimmed, parentId: _currentFolderId);
      debugPrint('DEBUG: Folder created with ID ${folder.id}');
      await _refresh();
      debugPrint('DEBUG: Refresh completed, folders count: ${_folders.length}');
    } catch (e) {
      debugPrint('DEBUG: Error creating folder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create folder: $e')),
        );
      }
    }
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
    try {
      // Show export options dialog
      final usePassword = await _showExportOptionsDialog();
      if (usePassword == null) {
        return; // User cancelled
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      
      final outPath = await _importExport.pickExportPath();
      if (outPath == null || outPath.trim().isEmpty) return;

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Exporting...')));

      try {
        final result = await _importExport.exportAllToZip(
          outputZipPath: outPath,
          usePassword: usePassword,
        );
        if (!mounted) return;
        messenger.hideCurrentSnackBar();

        if (usePassword) {
          // Show password dialog
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.lock, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Export Complete'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ZIP file saved successfully!'),
                  const SizedBox(height: 16),
                  const Text('File location:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SelectableText(
                    result.zipPath,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.key, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Text('Password:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          result.password,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.password));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password copied to clipboard')),
                    );
                  },
                  child: const Text('Copy Password'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Show no-password success dialog
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Export Complete'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ZIP file saved successfully!'),
                  const SizedBox(height: 16),
                  const Text('File location:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SelectableText(
                    result.zipPath,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text('No Password Required', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '✓ Memory-efficient import (200MB)\n'
                          '✓ Faster import with streaming\n'
                          '✓ No Out of Memory errors',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
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
      } catch (e) {
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start export: $e')),
        );
      }
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
            debugPrint('DEBUG: Bulk import completed, closing dialog and refreshing');
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
                color: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
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
              final navigator = Navigator.of(context);
              // Clean up temp folder
              await _yomikiru.cleanupTempFolder(tempPath);
              if (mounted) {
                navigator.pop();
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
                color: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📋 Next Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('1. Install Yomikiru at C:\\Users\\raysa\\AppData\\Local\\yomikiru\\Yomikiru.exe and try again'),
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
              final navigator = Navigator.of(context);
              // Clean up temp folder
              await _yomikiru.cleanupTempFolder(tempPath);
              if (mounted) {
                navigator.pop();
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
        const PopupMenuItem(
          value: 'yomikiru',
          child: Row(
            children: [
              Icon(Icons.auto_stories, size: 20),
              SizedBox(width: 12),
              Text('Open in Yomikiru'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'move',
          child: Row(
            children: [
              Icon(Icons.drive_file_move_outline, size: 20),
              SizedBox(width: 12),
              Text('Move'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.drive_file_rename_outline, size: 20),
              SizedBox(width: 12),
              Text('Rename'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
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

  /// Export folder as encrypted archive for PC-to-phone transfer
  Future<void> _exportFolderEncrypted(VaultFolder folder) async {
    try {
      // Show export options dialog
      final usePassword = await _showExportOptionsDialog();
      if (usePassword == null) {
        return; // User cancelled
      }

      String? password;
      if (usePassword) {
        // Show password dialog
        password = await _showPasswordDialog(
          title: 'Set Export Password',
          message: 'Enter a password to encrypt the export file.\nYou will need this password to import on your phone:',
        );
        if (password == null || password.isEmpty) {
          return; // User cancelled or empty password
        }
      }

      // Choose export location
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Encrypted Vault',
        fileName: '${folder.name}_encrypted.vault',
        type: FileType.custom,
        allowedExtensions: ['vault'],
      );

      if (outputPath == null) {
        return; // User cancelled
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);

      // Show enhanced progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ExportProgressDialog(
          encryptedExport: _encryptedExport,
          folder: folder,
          password: password ?? '', // Empty password for unencrypted
          outputPath: outputPath,
          onComplete: (result) {
            Navigator.pop(context); // Close progress dialog
            if (result.success) {
              _showEncryptedExportSuccessDialog(result, password, usePassword);
            } else {
              messenger.showSnackBar(
                SnackBar(content: Text('Export failed: ${result.message}')),
              );
            }
          },
          onError: (error) {
            Navigator.pop(context); // Close progress dialog
            messenger.showSnackBar(
              SnackBar(content: Text('Export failed: $error')),
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start export: $e')),
        );
      }
    }
  }

  /// Show dialog to choose export options (password or no password)
  Future<bool?> _showExportOptionsDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose how to export your vault:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '📱 For Android Import:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Without Password (Recommended)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Uses only 200MB memory\n'
                    '• Faster import (streaming)\n'
                    '• No Out of Memory errors\n'
                    '• Files encrypted in vault anyway',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'With Password',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Uses 1.2GB+ memory\n'
                    '• Slower import\n'
                    '• May cause Out of Memory\n'
                    '• Requires closing other apps',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('With Password'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Without Password (Recommended)'),
          ),
        ],
      ),
    );
  }

  void _showEncryptedExportSuccessDialog(EncryptedExportResult result, String? password, bool usePassword) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(usePassword ? Icons.lock : Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(usePassword ? 'Encrypted Export Ready' : 'Export Ready'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message),
              const SizedBox(height: 16),
              
              // Password reminder (only if password was used)
              if (usePassword && password != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.key, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Text('Remember this password:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        password,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You will need this password to import the file on your phone.',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // No password info
              if (!usePassword) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text('No Password Required', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '✓ Memory-efficient import (200MB)\n'
                        '✓ Faster import with streaming\n'
                        '✓ No Out of Memory errors\n'
                        '✓ Files are encrypted in vault',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              const Text('Export file location:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  result.outputPath,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              
              const SizedBox(height: 16),
              Text(
                '📱 Next steps:\n'
                '1. Transfer this .vault file to your Android device\n'
                '2. Open Local Vault on Android\n'
                '3. Use "Import Encrypted Vault" from the menu\n'
                '4. Select the .vault file from Downloads\n'
                '${usePassword ? "5. Enter the password shown above" : "5. No password needed - just import!"}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          if (usePassword && password != null)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: password));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password copied to clipboard')),
                );
              },
              child: const Text('Copy Password'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordDialog({
    required String title,
    required String message,
  }) async {
    String? password;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                helperText: 'Use a strong password for security',
              ),
              onChanged: (value) => password = value,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, password),
            child: const Text('Create Export'),
          ),
        ],
      ),
    );
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
      onPopInvoked: (didPop) async {
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
              tooltip: 'Clear Cache',
              onPressed: _clearCacheQuick,
              icon: const Icon(Icons.cleaning_services),
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
                              ? RepaintBoundary( // Strategic RepaintBoundary for checkbox animation
                                  child: Checkbox(
                                    value: _selectedFolderIds.contains(folder.id),
                                    onChanged: (_) => _toggleFolderSelection(folder.id),
                                  ),
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
                                      leading: const Icon(Icons.lock),
                                      title: const Text('Export Encrypted'),
                                      subtitle: const Text('For PC-to-phone transfer'),
                                      onTap: () => Navigator.pop(context, 'export_encrypted'),
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
                            if (action == 'export_encrypted') await _exportFolderEncrypted(folder);
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
                              ? RepaintBoundary( // Strategic RepaintBoundary for checkbox animation
                                  child: Checkbox(
                                    value: _selectedFileIds.contains(file.id),
                                    onChanged: (_) => _toggleFileSelection(file.id),
                                  ),
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
                                          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                                          : Theme.of(context).colorScheme.surface,
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
                                      child: RepaintBoundary( // Strategic RepaintBoundary for selection animation
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
                    
                    // Load more button with RepaintBoundary for animation
                    if (_hasMoreFiles && !_loading)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: RepaintBoundary( // Strategic RepaintBoundary for button animation
                            child: _loadingMore
                                ? const CircularProgressIndicator()
                                : FilledButton.icon(
                                    onPressed: _loadMoreFiles,
                                    icon: const Icon(Icons.expand_more),
                                    label: Text('Load more (${_totalFileCount - _files.length} remaining)'),
                                  ),
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

  final bulk.BulkImportService bulkImport;
  final String sourceFolderPath;
  final int? destinationFolderId;
  final VoidCallback onComplete;

  @override
  State<_BulkImportProgressDialog> createState() => _BulkImportProgressDialogState();
}

class _BulkImportProgressDialogState extends State<_BulkImportProgressDialog> {
  String _currentProgress = 'Starting import...';
  bool _isComplete = false;
  bulk.BulkImportResult? _result;

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

/// Enhanced export progress dialog for Windows
class _ExportProgressDialog extends StatefulWidget {
  const _ExportProgressDialog({
    required this.encryptedExport,
    required this.folder,
    required this.password,
    required this.outputPath,
    required this.onComplete,
    required this.onError,
  });

  final EncryptedExportService encryptedExport;
  final VaultFolder folder;
  final String password;
  final String outputPath;
  final Function(EncryptedExportResult) onComplete;
  final Function(String) onError;

  @override
  State<_ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<_ExportProgressDialog> {
  String _currentStatus = 'Preparing export...';
  bool _isComplete = false;
  int _filesProcessed = 0;
  int _totalFiles = 0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startExport();
  }

  Future<void> _startExport() async {
    try {
      final result = await widget.encryptedExport.exportFolderAsEncryptedArchive(
        folder: widget.folder,
        password: widget.password,
        outputPath: widget.outputPath,
        onProgress: (status) {
          if (mounted) {
            setState(() {
              _currentStatus = status;
              // Parse progress from status like "Processing files: 50/200"
              final match = RegExp(r'(\d+)/(\d+)').firstMatch(status);
              if (match != null) {
                _filesProcessed = int.parse(match.group(1)!);
                _totalFiles = int.parse(match.group(2)!);
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isComplete = true);
        widget.onComplete(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isComplete = true);
        widget.onError(e.toString());
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalFiles > 0 ? _filesProcessed / _totalFiles : 0.0;
    final progressPercent = (progress * 100).toInt();
    
    // Calculate time estimation
    String timeEstimate = '';
    if (_startTime != null && _filesProcessed > 0 && !_isComplete && _totalFiles > 0) {
      final elapsed = DateTime.now().difference(_startTime!);
      final avgTimePerFile = elapsed.inMilliseconds / _filesProcessed;
      final remainingFiles = _totalFiles - _filesProcessed;
      final estimatedRemaining = Duration(milliseconds: (avgTimePerFile * remainingFiles).round());
      timeEstimate = 'Est. time remaining: ${_formatDuration(estimatedRemaining)}';
    }

    return PopScope(
      canPop: _isComplete, // Prevent closing during export
      child: AlertDialog(
        title: Text(_isComplete ? 'Export Complete' : 'Exporting Folder'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isComplete) ...[
                if (_totalFiles > 0) ...[
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text('Progress: $_filesProcessed / $_totalFiles files ($progressPercent%)'),
                  if (timeEstimate.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(timeEstimate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ] else ...[
                  const Center(child: CircularProgressIndicator()),
                ],
                const SizedBox(height: 16),
                Text(_currentStatus, style: const TextStyle(fontSize: 12)),
              ] else ...[
                const Center(child: Icon(Icons.check_circle, color: Colors.green, size: 48)),
                const SizedBox(height: 16),
                Text(_currentStatus),
              ],
            ],
          ),
        ),
        actions: _isComplete
            ? [
                FilledButton(
                  onPressed: () {
                    // Dialog will be closed by onComplete callback
                  },
                  child: const Text('Done'),
                ),
              ]
            : null,
      ),
    );
  }
}
