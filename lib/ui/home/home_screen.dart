import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import '../../app/export_coordinator.dart';
import '../../app/import_coordinator.dart';
import '../../models/vault_file.dart';
import '../../models/vault_folder.dart';
import '../../services/app_lifecycle_service.dart';
import '../../services/blob_store.dart';
import '../../services/native_crypto_engine.dart';
import '../../services/file_crypto_service.dart';
import '../../services/file_open_service.dart';
import '../../services/import_export_service.dart';
import '../../services/job_repository.dart';
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
import '../viewers/image_viewer_screen.dart';
import '../viewers/video_viewer_screen.dart';

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

  late final ImportCoordinator _importCoordinator = ImportCoordinator(
    repo: _repo,
    jobRepo: JobRepository(),
    blobStore: BlobStore(),
    // Use NativeCryptoEngine so v1 blobs route to BCrypt (Windows) or
    // javax.crypto (Android) for hardware-accelerated AES-256-GCM.
    // Falls back to DartCryptoEngine automatically for v0 blobs.
    crypto: NativeCryptoEngine(),
    storage: SecureStorageService.instance,
  );

  late final ExportCoordinator _exportCoordinator = ExportCoordinator(
    repo: _repo,
    crypto: const FileCryptoService(),
    storage: SecureStorageService.instance,
    jobRepo: JobRepository(),
    // Use NativeCryptoEngine so v1 blob decryption routes to BCrypt (Windows)
    // for hardware-accelerated AES-256-GCM — ~3,000 MB/s vs ~10 MB/s in Dart.
    // Falls back to DartCryptoEngine automatically for v0 blobs.
    cryptoEngine: NativeCryptoEngine(),
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
      _hasMoreFiles =
          moreFiles.length >= _pageSize && _files.length < _totalFileCount;
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
              _currentFolderId =
                  _folderStack.isEmpty ? null : _folderStack.last.id;
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
      items =
          items.where((f) => f.originalName.toLowerCase().contains(q)).toList();
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
          content:
              Text('Cache cleared successfully! All temporary files removed.'),
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
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
      debugPrint(
          'DEBUG: Creating folder "$trimmed" in parent $_currentFolderId');
      final folder =
          await _repo.createFolder(name: trimmed, parentId: _currentFolderId);
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

      final outPath = await _importExport.pickExportPath();
      if (outPath == null || outPath.trim().isEmpty) return;

      if (!mounted) return;

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ExportAllProgressDialog(
          importExport: _importExport,
          outputZipPath: outPath,
          usePassword: usePassword,
          onComplete: (result) {
            Navigator.pop(context); // Close progress dialog
            _showExportSuccessDialog(result, usePassword);
          },
          onError: (error) {
            Navigator.pop(context); // Close progress dialog
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Export failed: $error')),
              );
            }
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

  /// Save all vault content to local gallery (unencrypted ZIP)
  /// Windows: User chooses location
  /// Android: Saves to Downloads folder
  Future<void> _saveToLocalGallery() async {
    try {
      debugPrint('Starting Save to Local Gallery...');

      if (!mounted) return;

      String? outPath;

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop: Let user choose location
        outPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save to Local Gallery',
          fileName:
              'vault_gallery_${DateTime.now().millisecondsSinceEpoch}.zip',
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );

        if (outPath == null) {
          debugPrint('User cancelled file picker');
          return; // User cancelled
        }
      } else {
        // Android: Save to Downloads folder
        const downloadsPath = '/storage/emulated/0/Download';
        final fileName =
            'vault_gallery_${DateTime.now().millisecondsSinceEpoch}.zip';
        outPath = '$downloadsPath/$fileName';
        debugPrint('Android: Saving to $outPath');
      }

      if (!mounted) return;

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _SaveToGalleryProgressDialog(
          importExport: _importExport,
          outputZipPath: outPath!,
          onComplete: (result) {
            Navigator.pop(context); // Close progress dialog
            _showGallerySaveSuccessDialog(result);
          },
          onError: (error) {
            Navigator.pop(context); // Close progress dialog
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Save failed: $error')),
              );
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('Failed to start save to gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start save: $e')),
        );
      }
    }
  }

  /// Show gallery save success dialog
  void _showGallerySaveSuccessDialog(ExportAllResult result) {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Saved to Local Gallery'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'All vault content has been saved as an unencrypted ZIP file.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text('File Location:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    result.zipPath,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('Not Encrypted:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This ZIP file is NOT password protected. Anyone can open it with any ZIP tool.',
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

  /// Show export success dialog
  void _showExportSuccessDialog(ExportAllResult result, bool usePassword) {
    if (!mounted) return;

    if (usePassword) {
      // Show password dialog
      showDialog<void>(
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
              const Text('File location:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                        Text('Password:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      result.password,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
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
      showDialog<void>(
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
              const Text('File location:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                        Text('No Password',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                        'This ZIP can be imported on Android without password.'),
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
  }

  Future<void> _importZip() async {
    final messenger = ScaffoldMessenger.of(context);

    // Show recommendation dialog first
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import ZIP'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommended Method:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Extract the ZIP file using File Explorer'),
            Text('2. Use "Import Folder" from the menu'),
            SizedBox(height: 16),
            Text(
              'This is more reliable and uses less memory.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 16),
            Text('Do you still want to try importing the ZIP directly?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue with ZIP'),
          ),
        ],
      ),
    );

    if (shouldContinue != true) return;

    final zipPath = await _importExport.pickImportZipPath();
    if (zipPath == null || zipPath.trim().isEmpty) return;
    if (!mounted) return;

    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import ZIP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'ZIP password (if encrypted)',
                hintText: 'Leave empty if not password protected',
              ),
              autofocus: true,
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (password == null) return; // User cancelled

    final pw = password.trim();

    if (!mounted) return;

    // Use ImportCoordinator (streaming, memory-safe) instead of legacy
    // importFromZip (readAsBytes — OOM risk on large ZIPs).
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ZipImportProgressDialog(
        importCoordinator: _importCoordinator,
        zipPath: zipPath,
        password: pw,
        destinationFolderId: _currentFolderId,
        onComplete: () {
          Navigator.pop(context);
          _refresh();
        },
        onError: (error) {
          Navigator.pop(context);
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                    'Import failed: $error\n\nTry extracting the ZIP first, then use Import Folder.'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        },
      ),
    );
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
        builder: (_) => ImageViewerScreen(
          file: file,
          allFiles: _files,
        ),
      ));
      return;
    }
    if (isVideoFileName(file.originalName)) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VideoViewerScreen(file: file)));
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening ${file.originalName}...')));
    try {
      await _openService.decryptToTempAndOpen(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Open failed: $e')));
    }
  }

  Future<void> _importFolder() async {
    // Use directory picker (Windows only for now)
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Folder import is currently only supported on Windows')),
      );
      return;
    }

    try {
      // For now, we'll use a simple dialog to get folder path
      final controller = TextEditingController();
      bool includeVideo = false;
      final folderPath = await showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Import Folder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Enter the full path to the folder containing images:'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: r'C:\Users\YourName\Pictures\Manga\Series1',
                    labelText: 'Folder Path',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include video files (.mp4, .mkv, .avi)'),
                  value: includeVideo,
                  onChanged: (v) =>
                      setDialogState(() => includeVideo = v ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Import'),
              ),
            ],
          ),
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

      // Show progress dialog — uses ImportCoordinator (FEAT-003).
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ImportCoordinatorProgressDialog(
          importCoordinator: _importCoordinator,
          sourceFolderPath: folderPath,
          destinationFolderId: _currentFolderId,
          includeVideo: includeVideo,
          onComplete: () {
            debugPrint(
                'DEBUG: ImportCoordinator import completed, closing dialog and refreshing');
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
    if (!mounted) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _YomikiruProgressDialog(
        yomikiru: _yomikiru,
        folder: folder,
        onComplete: (result) {
          Navigator.pop(context); // Close progress dialog
          if (result.success) {
            _showYomikiruSuccessDialog(folder.name, result.tempFolderPath);
          } else {
            _showYomikiruNotFoundDialog(result.tempFolderPath, result.error);
          }
        },
        onError: (error) {
          Navigator.pop(context); // Close progress dialog
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to open in Yomikiru: $error')),
            );
          }
        },
      ),
    );
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
            const Text('Images exported to:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      tempPath,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tempPath));
                      messenger.showSnackBar(
                        const SnackBar(
                            content: Text('Path copied to clipboard!')),
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
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 Tip:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(
                      'If images don\'t appear in Yomikiru, copy the path above and set it as the manga folder in Yomikiru\'s settings.'),
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
              await Process.start('explorer', [tempPath],
                  mode: ProcessStartMode.detached);
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
                  const SnackBar(
                      content: Text('Temp folder cleaned up successfully!')),
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
            const Text(
                'Yomikiru was not found, but your images have been exported to:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      tempPath,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tempPath));
                      messenger.showSnackBar(
                        const SnackBar(
                            content: Text('Path copied to clipboard!')),
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
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📋 Next Steps:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                      '1. Install Yomikiru at C:\\Users\\raysa\\AppData\\Local\\yomikiru\\Yomikiru.exe and try again'),
                  Text(
                      '2. Copy the path above and set it in Yomikiru settings'),
                  Text(
                      '3. Open the folder manually in your preferred manga reader'),
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
              await Process.start('explorer', [tempPath],
                  mode: ProcessStartMode.detached);
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
                  const SnackBar(
                      content: Text('Temp folder cleaned up successfully!')),
                );
              }
            },
            child: const Text('Clean Up'),
          ),
        ],
      ),
    );
  }

  void _showFolderContextMenu(
      BuildContext context, Offset position, VaultFolder folder) {
    // Use showMenu with proper positioning
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
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
          value: 'export_zip',
          child: Row(
            children: [
              Icon(Icons.folder_zip, size: 20),
              SizedBox(width: 12),
              Text('Export as ZIP'),
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
          case 'export_zip':
            _exportFolderAsZip(folder);
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
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
        content:
            const Text('This deletes the folder and everything inside it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteFolderRecursive(folderId: folder.id);
    await _refresh();
  }

  Future<void> _moveFolder(VaultFolder folder) async {
    final dest = await Navigator.of(context).push<int?>(
      MaterialPageRoute(
          builder: (_) =>
              FolderPickerScreen(repo: _repo, title: 'Move folder to')),
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

  /// Export single folder as ZIP (Windows only)
  Future<void> _exportFolderAsZip(VaultFolder folder) async {
    try {
      if (!mounted) return;

      // Choose export location
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save ZIP File',
        fileName: '${folder.name}.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (outputPath == null) {
        return; // User cancelled
      }

      if (!mounted) return;

      // Show progress dialog — uses ExportCoordinator (FEAT-003).
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ExportCoordinatorProgressDialog(
          exportCoordinator: _exportCoordinator,
          folder: folder,
          outputZipPath: outputPath,
          onComplete: () {
            Navigator.pop(context); // Close progress dialog
            _showExportSuccessDialog(
              ExportAllResult(
                zipPath: outputPath,
                password: '',
              ),
              false, // ExportCoordinator doesn't add ZIP password
            );
          },
          onError: (error) {
            Navigator.pop(context); // Close progress dialog
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Export failed: $error')),
              );
            }
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteFile(fileId: file.id);
    await _refresh();
  }

  Future<void> _moveFile(VaultFile file) async {
    final dest = await Navigator.of(context).push<int?>(
      MaterialPageRoute(
          builder: (_) =>
              FolderPickerScreen(repo: _repo, title: 'Move file to')),
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
    final selectedFiles =
        _files.where((f) => _selectedFileIds.contains(f.id)).toList();
    final selectedFolders =
        _folders.where((f) => _selectedFolderIds.contains(f.id)).toList();

    final totalItems = selectedFiles.length + selectedFolders.length;
    if (totalItems == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete selected items?'),
        content: Text('This will delete $totalItems items permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
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

  Future<void> _moveSelectedItems() async {
    final selectedFiles =
        _files.where((f) => _selectedFileIds.contains(f.id)).toList();
    final selectedFolders =
        _folders.where((f) => _selectedFolderIds.contains(f.id)).toList();

    final totalItems = selectedFiles.length + selectedFolders.length;
    if (totalItems == 0) return;

    // Show folder picker
    final dest = await Navigator.push<int?>(
      context,
      MaterialPageRoute(
        builder: (_) => FolderPickerScreen(
          repo: _repo,
          title: 'Move $totalItems items to',
        ),
      ),
    );

    if (!mounted || dest == null) return;

    try {
      // Move files
      for (final file in selectedFiles) {
        await _repo.moveFile(fileId: file.id, newParentFolderId: dest);
      }

      // Batch move folders for better performance
      if (selectedFolders.isNotEmpty) {
        await _repo.batchMoveFolders(
          folderIds: selectedFolders.map((f) => f.id).toList(),
          newParentId: dest,
        );
      }

      setState(() {
        _multiSelectMode = false;
        _selectedFileIds.clear();
        _selectedFolderIds.clear();
      });

      await _refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved $totalItems items successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Move failed: $e')),
        );
      }
    }
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
              ? Text(
                  '${_selectedFileIds.length + _selectedFolderIds.length} selected')
              : Text(_folderStack.isEmpty
                  ? 'Local Vault'
                  : _folderStack.last.name),
          actions: _multiSelectMode
              ? [
                  if (_selectedFileIds.isNotEmpty ||
                      _selectedFolderIds.isNotEmpty) ...[
                    IconButton(
                      tooltip: 'Move selected',
                      onPressed: _moveSelectedItems,
                      icon: const Icon(Icons.drive_file_move),
                    ),
                    IconButton(
                      tooltip: 'Delete selected',
                      onPressed: _deleteSelectedItems,
                      icon: const Icon(Icons.delete),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Cancel selection',
                    onPressed: _toggleMultiSelectMode,
                    icon: const Icon(Icons.close),
                  ),
                ]
              : [
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
                    icon:
                        Icon(_query.isEmpty ? Icons.search : Icons.search_off),
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
                      if (value == 'save_gallery') await _saveToLocalGallery();
                      if (value == 'lock') {
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AuthGate()),
                          (_) => false,
                        );
                      }
                      if (value == 'sort_name') {
                        setState(() => _sort = 'name');
                      }
                      if (value == 'sort_date') {
                        setState(() => _sort = 'date');
                      }
                      if (value == 'sort_size') {
                        setState(() => _sort = 'size');
                      }
                      if (value == 'sort_dir') {
                        setState(() => _sortAsc = !_sortAsc);
                      }
                      if (value == 'view_toggle') {
                        setState(() => _gridView = !_gridView);
                      }
                      if (value == 'settings' && context.mounted) {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const SettingsScreen()));
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                          value: 'import_folder', child: Text('Import Folder')),
                      PopupMenuItem(value: 'import', child: Text('Import ZIP')),
                      PopupMenuItem(value: 'export', child: Text('Export')),
                      PopupMenuItem(
                          value: 'save_gallery',
                          child: Text('Save to Local Gallery')),
                      PopupMenuDivider(),
                      PopupMenuItem(
                          value: 'sort_name', child: Text('Sort: Name')),
                      PopupMenuItem(
                          value: 'sort_date', child: Text('Sort: Date')),
                      PopupMenuItem(
                          value: 'sort_size', child: Text('Sort: Size')),
                      PopupMenuItem(
                          value: 'sort_dir',
                          child: Text('Toggle ascending/descending')),
                      PopupMenuItem(
                          value: 'view_toggle',
                          child: Text('Toggle list/grid')),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: _folderStack.isEmpty
                          ? const SizedBox.shrink()
                          : _breadcrumbs(),
                    ),
                    if (_query.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text('Filter: "$_query"')),
                            TextButton(
                                onPressed: () => setState(() => _query = ''),
                                child: const Text('Clear')),
                          ],
                        ),
                      ),
                    ..._visibleFolders.map(
                      (folder) => GestureDetector(
                        onSecondaryTapDown: (details) {
                          _showFolderContextMenu(
                              context, details.globalPosition, folder);
                        },
                        child: ListTile(
                          leading: _multiSelectMode
                              ? RepaintBoundary(
                                  // Strategic RepaintBoundary for checkbox animation
                                  child: Checkbox(
                                    value:
                                        _selectedFolderIds.contains(folder.id),
                                    onChanged: (_) =>
                                        _toggleFolderSelection(folder.id),
                                  ),
                                )
                              : const Icon(Icons.folder),
                          title: Text(folder.name),
                          onTap: _multiSelectMode
                              ? () => _toggleFolderSelection(folder.id)
                              : () => _openFolder(folder),
                          onLongPress: _multiSelectMode
                              ? null
                              : () async {
                                  final action =
                                      await showModalBottomSheet<String>(
                                    context: context,
                                    builder: (context) => SafeArea(
                                      child: Wrap(
                                        children: [
                                          ListTile(
                                            leading:
                                                const Icon(Icons.auto_stories),
                                            title:
                                                const Text('Open in Yomikiru'),
                                            onTap: () => Navigator.pop(
                                                context, 'yomikiru'),
                                          ),
                                          ListTile(
                                            leading:
                                                const Icon(Icons.folder_zip),
                                            title: const Text('Export as ZIP'),
                                            subtitle: const Text(
                                                'Export this folder only'),
                                            onTap: () => Navigator.pop(
                                                context, 'export_zip'),
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                                Icons.drive_file_move_outline),
                                            title: const Text('Move'),
                                            onTap: () =>
                                                Navigator.pop(context, 'move'),
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons
                                                .drive_file_rename_outline),
                                            title: const Text('Rename'),
                                            onTap: () => Navigator.pop(
                                                context, 'rename'),
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                                Icons.delete_outline),
                                            title: const Text('Delete'),
                                            onTap: () => Navigator.pop(
                                                context, 'delete'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (action == 'yomikiru') {
                                    await _openFolderInYomikiru(folder);
                                  }
                                  if (action == 'export_zip') {
                                    await _exportFolderAsZip(folder);
                                  }
                                  if (action == 'move') {
                                    await _moveFolder(folder);
                                  }
                                  if (action == 'rename') {
                                    await _renameFolder(folder);
                                  }
                                  if (action == 'delete') {
                                    await _deleteFolder(folder);
                                  }
                                },
                        ),
                      ),
                    ),
                    if (!_gridView)
                      ..._visibleFiles.map(
                        (file) => ListTile(
                          leading: _multiSelectMode
                              ? RepaintBoundary(
                                  // Strategic RepaintBoundary for checkbox animation
                                  child: Checkbox(
                                    value: _selectedFileIds.contains(file.id),
                                    onChanged: (_) =>
                                        _toggleFileSelection(file.id),
                                  ),
                                )
                              : isImageFileName(file.originalName)
                                  ? Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.image,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    )
                                  : const Icon(Icons.insert_drive_file),
                          title: Text(file.originalName),
                          subtitle: Text(
                              '${formatBytes(file.byteSize)} • ${formatLocalDateTime(file.createdAt)}'),
                          onTap: _multiSelectMode
                              ? () => _toggleFileSelection(file.id)
                              : () => _openFile(file),
                          onLongPress: _multiSelectMode
                              ? null
                              : () async {
                                  final action =
                                      await showModalBottomSheet<String>(
                                    context: context,
                                    builder: (context) => SafeArea(
                                      child: Wrap(
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                                Icons.drive_file_move_outline),
                                            title: const Text('Move'),
                                            onTap: () =>
                                                Navigator.pop(context, 'move'),
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons
                                                .drive_file_rename_outline),
                                            title: const Text('Rename'),
                                            onTap: () => Navigator.pop(
                                                context, 'rename'),
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                                Icons.delete_outline),
                                            title: const Text('Delete'),
                                            onTap: () => Navigator.pop(
                                                context, 'delete'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (action == 'move') {
                                    await _moveFile(file);
                                  }
                                  if (action == 'rename') {
                                    await _renameFile(file);
                                  }
                                  if (action == 'delete') {
                                    await _deleteFile(file);
                                  }
                                },
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _visibleFiles.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
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
                              onLongPress: _multiSelectMode
                                  ? null
                                  : () async {
                                      final action =
                                          await showModalBottomSheet<String>(
                                        context: context,
                                        builder: (context) => SafeArea(
                                          child: Wrap(
                                            children: [
                                              ListTile(
                                                leading: const Icon(Icons
                                                    .drive_file_move_outline),
                                                title: const Text('Move'),
                                                onTap: () => Navigator.pop(
                                                    context, 'move'),
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons
                                                    .drive_file_rename_outline),
                                                title: const Text('Rename'),
                                                onTap: () => Navigator.pop(
                                                    context, 'rename'),
                                              ),
                                              ListTile(
                                                leading: const Icon(
                                                    Icons.delete_outline),
                                                title: const Text('Delete'),
                                                onTap: () => Navigator.pop(
                                                    context, 'delete'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                      if (action == 'move') {
                                        await _moveFile(file);
                                      }
                                      if (action == 'rename') {
                                        await _renameFile(file);
                                      }
                                      if (action == 'delete') {
                                        await _deleteFile(file);
                                      }
                                    },
                              child: Stack(
                                children: [
                                  Ink(
                                    decoration: BoxDecoration(
                                      color: _multiSelectMode &&
                                              _selectedFileIds.contains(file.id)
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withOpacity(0.3)
                                          : Theme.of(context)
                                              .colorScheme
                                              .surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: _multiSelectMode &&
                                              _selectedFileIds.contains(file.id)
                                          ? Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              width: 2)
                                          : null,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Center(
                                              child: isImg
                                                  ? Container(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primaryContainer,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: Icon(
                                                        Icons.image,
                                                        size: 40,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onPrimaryContainer,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons
                                                          .insert_drive_file_outlined,
                                                      size: 40),
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
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (_multiSelectMode)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: RepaintBoundary(
                                        // Strategic RepaintBoundary for selection animation
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: _selectedFileIds
                                                    .contains(file.id)
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .surface,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline,
                                            ),
                                          ),
                                          child: Icon(
                                            _selectedFileIds.contains(file.id)
                                                ? Icons.check
                                                : null,
                                            color: _selectedFileIds
                                                    .contains(file.id)
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary
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
                          child: RepaintBoundary(
                            // Strategic RepaintBoundary for button animation
                            child: _loadingMore
                                ? const CircularProgressIndicator()
                                : FilledButton.icon(
                                    onPressed: _loadMoreFiles,
                                    icon: const Icon(Icons.expand_more),
                                    label: Text(
                                        'Load more (${_totalFileCount - _files.length} remaining)'),
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

// ---------------------------------------------------------------------------
// ImportCoordinator progress dialog (FEAT-003)
// ---------------------------------------------------------------------------

class _ImportCoordinatorProgressDialog extends StatefulWidget {
  const _ImportCoordinatorProgressDialog({
    required this.importCoordinator,
    required this.sourceFolderPath,
    required this.destinationFolderId,
    required this.onComplete,
    this.includeVideo = false,
  });

  final ImportCoordinator importCoordinator;
  final String sourceFolderPath;
  final int? destinationFolderId;
  final VoidCallback onComplete;
  final bool includeVideo;

  @override
  State<_ImportCoordinatorProgressDialog> createState() =>
      _ImportCoordinatorProgressDialogState();
}

class _ImportCoordinatorProgressDialogState
    extends State<_ImportCoordinatorProgressDialog> {
  String _statusText = 'Starting import…';
  int _completedFiles = 0;
  int _totalFiles = 0;
  bool _isComplete = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  Future<void> _startImport() async {
    try {
      await for (final progress in widget.importCoordinator.importFolder(
        widget.sourceFolderPath,
        widget.destinationFolderId,
        includeVideo: widget.includeVideo,
        onStatus: (msg) {
          if (mounted) setState(() => _statusText = msg);
        },
      )) {
        if (!mounted) break;
        setState(() {
          _completedFiles = progress.completedFiles;
          _totalFiles = progress.totalFiles;
        });
      }
      if (mounted) {
        setState(() {
          _isComplete = true;
          _statusText = 'Import complete!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isComplete = true;
          _errorText = e.toString();
          _statusText = 'Import failed';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _totalFiles > 0 ? _completedFiles / _totalFiles : null;
    return PopScope(
      canPop: _isComplete,
      child: AlertDialog(
        title: Text(_isComplete ? 'Import Complete' : 'Importing Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isComplete) const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_statusText),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            LinearProgressIndicator(value: fraction),
            const SizedBox(height: 4),
            if (_totalFiles > 0)
              Text('$_completedFiles / $_totalFiles files',
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (_isComplete)
            FilledButton(
              onPressed: widget.onComplete,
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ExportCoordinator progress dialog (FEAT-003)
// ---------------------------------------------------------------------------

class _ExportCoordinatorProgressDialog extends StatefulWidget {
  const _ExportCoordinatorProgressDialog({
    required this.exportCoordinator,
    required this.folder,
    required this.outputZipPath,
    required this.onComplete,
    required this.onError,
  });

  final ExportCoordinator exportCoordinator;
  final VaultFolder folder;
  final String outputZipPath;
  final VoidCallback onComplete;
  final void Function(String) onError;

  @override
  State<_ExportCoordinatorProgressDialog> createState() =>
      _ExportCoordinatorProgressDialogState();
}

class _ExportCoordinatorProgressDialogState
    extends State<_ExportCoordinatorProgressDialog> {
  int _latestCompleted = 0;
  int _latestTotal = 0;
  int _latestProcessedBytes = 0;
  int _latestTotalBytes = 0;
  bool _isComplete = false;
  bool _pendingRebuild = false;

  @override
  void initState() {
    super.initState();
    _startExport();
  }

  // Coalesce progress events into at most one rebuild per frame so a burst of
  // ExportProgress yields does not thrash the UI isolate (eliminates the
  // spinner jitter that prompted this task).
  void _onProgress(ExportProgress p) {
    _latestCompleted = p.completedFiles;
    _latestTotal = p.totalFiles;
    _latestProcessedBytes = p.processedBytes;
    _latestTotalBytes = p.totalBytes;
    if (_pendingRebuild) return;
    _pendingRebuild = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
      _pendingRebuild = false;
    });
  }

  Future<void> _startExport() async {
    try {
      await for (final progress in widget.exportCoordinator.exportFolder(
        widget.folder.id,
        widget.outputZipPath,
      )) {
        if (!mounted) break;
        _onProgress(progress);
      }
      if (mounted) {
        setState(() => _isComplete = true);
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isComplete = true);
        widget.onError(e.toString());
      }
    }
  }

  static String _fmtMb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final fraction = _latestTotal > 0
        ? (_latestCompleted / _latestTotal).clamp(0.0, 1.0)
        : null;
    return PopScope(
      canPop: _isComplete,
      child: AlertDialog(
        title: Text(_isComplete ? 'Export Complete' : 'Exporting Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isComplete) const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_isComplete
                ? 'Export completed successfully!'
                : 'Exporting ${widget.folder.name}…'),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: fraction),
            const SizedBox(height: 4),
            if (_latestTotal > 0)
              Text('$_latestCompleted / $_latestTotal files',
                  style: const TextStyle(fontSize: 12)),
            if (_latestTotalBytes > 0)
              Text(
                '${_fmtMb(_latestProcessedBytes)} / ${_fmtMb(_latestTotalBytes)} MB',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: _isComplete
            ? [
                FilledButton(
                  onPressed: () {
                    // Closed by onComplete callback
                  },
                  child: const Text('Done'),
                ),
              ]
            : null,
      ),
    );
  }
}

class _ExportAllProgressDialog extends StatefulWidget {
  const _ExportAllProgressDialog({
    required this.importExport,
    required this.outputZipPath,
    required this.usePassword,
    required this.onComplete,
    required this.onError,
  });

  final ImportExportService importExport;
  final String outputZipPath;
  final bool usePassword;
  final Function(ExportAllResult) onComplete;
  final Function(String) onError;

  @override
  State<_ExportAllProgressDialog> createState() =>
      _ExportAllProgressDialogState();
}

class _ExportAllProgressDialogState extends State<_ExportAllProgressDialog> {
  String _currentStatus = 'Preparing export...';
  bool _isComplete = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startExport();
  }

  Future<void> _startExport() async {
    try {
      setState(() => _currentStatus = 'Decrypting files...');
      await Future.delayed(const Duration(milliseconds: 100)); // Let UI update

      final result = await widget.importExport.exportAllToZip(
        outputZipPath: widget.outputZipPath,
        usePassword: widget.usePassword,
      );

      if (mounted) {
        setState(() {
          _isComplete = true;
          _currentStatus = 'Export completed successfully!';
        });
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
    // Calculate elapsed time
    String elapsedTime = '';
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!);
      elapsedTime = 'Elapsed: ${_formatDuration(elapsed)}';
    }

    return PopScope(
      canPop: _isComplete, // Prevent closing during export
      child: AlertDialog(
        title: Text(_isComplete ? 'Export Complete' : 'Exporting Vault'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isComplete) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 24),
                Text(_currentStatus, style: const TextStyle(fontSize: 14)),
                if (elapsedTime.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(elapsedTime,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                const SizedBox(height: 16),
                const Text(
                  'This may take a few minutes depending on vault size...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else ...[
                const Center(
                    child: Icon(Icons.check_circle,
                        color: Colors.green, size: 48)),
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

/// Save to Gallery progress dialog (unencrypted ZIP export)
class _SaveToGalleryProgressDialog extends StatefulWidget {
  const _SaveToGalleryProgressDialog({
    required this.importExport,
    required this.outputZipPath,
    required this.onComplete,
    required this.onError,
  });

  final ImportExportService importExport;
  final String outputZipPath;
  final Function(ExportAllResult) onComplete;
  final Function(String) onError;

  @override
  State<_SaveToGalleryProgressDialog> createState() =>
      _SaveToGalleryProgressDialogState();
}

class _SaveToGalleryProgressDialogState
    extends State<_SaveToGalleryProgressDialog> {
  String _currentStatus = 'Preparing to save...';
  bool _isComplete = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startSave();
  }

  Future<void> _startSave() async {
    try {
      setState(() => _currentStatus = 'Decrypting files...');
      await Future.delayed(const Duration(milliseconds: 100)); // Let UI update

      // Export without password (unencrypted ZIP)
      final result = await widget.importExport.exportAllToZip(
        outputZipPath: widget.outputZipPath,
        usePassword: false, // No password = unencrypted
      );

      if (mounted) {
        setState(() {
          _isComplete = true;
          _currentStatus = 'Saved successfully!';
        });
        widget.onComplete(result);
      }
    } catch (e) {
      debugPrint('Save to gallery error: $e');
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
    // Calculate elapsed time
    String elapsedTime = '';
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!);
      elapsedTime = 'Elapsed: ${_formatDuration(elapsed)}';
    }

    return PopScope(
      canPop: _isComplete, // Prevent closing during save
      child: AlertDialog(
        title: Text(_isComplete ? 'Save Complete' : 'Saving to Local Gallery'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isComplete) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 24),
                Text(_currentStatus, style: const TextStyle(fontSize: 14)),
                if (elapsedTime.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(elapsedTime,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Creating unencrypted ZIP file...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else ...[
                const Center(
                    child: Icon(Icons.check_circle,
                        color: Colors.green, size: 48)),
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

/// Yomikiru progress dialog for Windows
class _YomikiruProgressDialog extends StatefulWidget {
  const _YomikiruProgressDialog({
    required this.yomikiru,
    required this.folder,
    required this.onComplete,
    required this.onError,
  });

  final YomikiruIntegrationService yomikiru;
  final VaultFolder folder;
  final Function(YomikiruLaunchResult) onComplete;
  final Function(String) onError;

  @override
  State<_YomikiruProgressDialog> createState() =>
      _YomikiruProgressDialogState();
}

class _YomikiruProgressDialogState extends State<_YomikiruProgressDialog> {
  String _currentStatus = 'Preparing export...';
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _startExport();
  }

  Future<void> _startExport() async {
    try {
      final result = await widget.yomikiru.openFolderInYomikiru(
        widget.folder,
        onProgress: (status) {
          if (mounted) {
            setState(() {
              _currentStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isComplete = true;
          _currentStatus = 'Export completed successfully!';
        });

        // Wait a moment to show completion, then call callback
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          widget.onComplete(result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isComplete = true;
          _currentStatus = 'Export failed: $e';
        });

        // Wait a moment to show error, then call callback
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          widget.onError(e.toString());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isComplete,
      child: AlertDialog(
        title: Text(_isComplete ? 'Export Complete' : 'Opening in Yomikiru'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isComplete) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 24),
                Text(_currentStatus, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                const Text(
                  'Decrypting and exporting images...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else ...[
                const Center(
                    child: Icon(Icons.check_circle,
                        color: Colors.green, size: 48)),
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

/// Export Folder as ZIP progress dialog for Windows
class _ExportFolderZipProgressDialog extends StatefulWidget {
  const _ExportFolderZipProgressDialog({
    required this.importExport,
    required this.folder,
    required this.outputZipPath,
    required this.usePassword,
    required this.onComplete,
    required this.onError,
  });

  final ImportExportService importExport;
  final VaultFolder folder;
  final String outputZipPath;
  final bool usePassword;
  final Function(ExportAllResult) onComplete;
  final Function(String) onError;

  @override
  State<_ExportFolderZipProgressDialog> createState() =>
      _ExportFolderZipProgressDialogState();
}

class _ExportFolderZipProgressDialogState
    extends State<_ExportFolderZipProgressDialog> {
  String _currentStatus = 'Preparing export...';
  bool _isComplete = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startExport();
  }

  Future<void> _startExport() async {
    try {
      setState(() => _currentStatus = 'Decrypting files from folder...');
      await Future.delayed(const Duration(milliseconds: 100)); // Let UI update

      final result = await widget.importExport.exportFolderToZip(
        folderId: widget.folder.id,
        outputZipPath: widget.outputZipPath,
        usePassword: widget.usePassword,
      );

      if (mounted) {
        setState(() {
          _isComplete = true;
          _currentStatus = 'Export completed successfully!';
        });
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
    // Calculate elapsed time
    String elapsedTime = '';
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!);
      elapsedTime = 'Elapsed: ${_formatDuration(elapsed)}';
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
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 24),
                Text(_currentStatus, style: const TextStyle(fontSize: 14)),
                if (elapsedTime.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(elapsedTime,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                const SizedBox(height: 16),
                Text(
                  'Exporting: ${widget.folder.name}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold),
                ),
              ] else ...[
                const Center(
                    child: Icon(Icons.check_circle,
                        color: Colors.green, size: 48)),
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

// ---------------------------------------------------------------------------
// ZIP import via ImportCoordinator progress dialog (ISSUE-003 fix)
// Replaces the legacy importFromZip (readAsBytes) path on desktop.
// ---------------------------------------------------------------------------

class _ZipImportProgressDialog extends StatefulWidget {
  const _ZipImportProgressDialog({
    required this.importCoordinator,
    required this.zipPath,
    required this.destinationFolderId,
    required this.onComplete,
    required this.onError,
    required this.password,
  });

  final ImportCoordinator importCoordinator;
  final String zipPath;
  final int? destinationFolderId;
  final VoidCallback onComplete;
  final void Function(String) onError;
  final String password;

  @override
  State<_ZipImportProgressDialog> createState() =>
      _ZipImportProgressDialogState();
}

class _ZipImportProgressDialogState extends State<_ZipImportProgressDialog> {
  String _statusText = 'Opening ZIP...';
  int _completedFiles = 0;
  int _totalFiles = 0;
  bool _isComplete = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  Future<void> _startImport() async {
    try {
      await for (final progress in widget.importCoordinator.importZip(
        widget.zipPath,
        widget.destinationFolderId,
        password: widget.password,
        onStatus: (msg) {
          if (mounted) setState(() => _statusText = msg);
        },
      )) {
        if (!mounted) break;
        setState(() {
          _completedFiles = progress.completedFiles;
          _totalFiles = progress.totalFiles;
        });
      }
      if (mounted) {
        setState(() {
          _isComplete = true;
          _statusText = 'Import complete!';
        });
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isComplete = true;
          _errorText = e.toString();
          _statusText = 'Import failed';
        });
        widget.onError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _totalFiles > 0 ? _completedFiles / _totalFiles : null;
    return PopScope(
      canPop: _isComplete,
      child: AlertDialog(
        title: Text(_isComplete ? 'Import Complete' : 'Importing ZIP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isComplete) const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_statusText),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            LinearProgressIndicator(value: fraction),
            const SizedBox(height: 4),
            if (_totalFiles > 0)
              Text('$_completedFiles / $_totalFiles files',
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (_isComplete)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }
}
