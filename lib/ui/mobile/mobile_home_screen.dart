import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:math';

import '../../app/import_coordinator.dart';
import '../../models/vault_file.dart';
import '../../models/vault_folder.dart';
import '../../services/android_manga_service.dart';
import '../../services/app_lifecycle_service.dart';
import '../../services/blob_store.dart';
import '../../services/native_crypto_engine.dart';
import '../../services/file_crypto_service.dart';
import '../../services/file_open_service.dart';
import '../../services/job_repository.dart';
import '../../services/secure_storage_service.dart';
import '../../services/settings_service.dart';
import '../../services/vault_open_service.dart';
import '../../services/vault_repository.dart';
import '../../utils/vault_format.dart';
import '../auth/auth_gate.dart';
import '../settings/settings_screen.dart';
import '../search/global_search_screen.dart';
import '../viewers/image_viewer_screen.dart';
import '../viewers/video_viewer_screen.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  // Use plain VaultRepository — EnhancedVaultRepository was starting thermal
  // monitoring timers in its constructor causing PERF-007 timer leaks (OPT-005).
  final VaultRepository _repo = VaultRepository(
    crypto: const FileCryptoService(),
    secureStorage: SecureStorageService.instance,
  );

  late final VaultOpenService _openService = VaultOpenService(
    crypto: const FileCryptoService(),
    secureStorage: SecureStorageService.instance,
    opener: FileOpenService(),
  );

  late final SettingsService _settingsService = SettingsService();

  // ImportCoordinator wires all new imports through JobRunner (FEAT-003).
  late final ImportCoordinator _importCoordinator = ImportCoordinator(
    repo: _repo,
    jobRepo: JobRepository(),
    blobStore: BlobStore(),
    // Use NativeCryptoEngine so v1 blobs route to javax.crypto (Android)
    // for hardware-accelerated AES-256-GCM via BoringSSL + ARMv8 CE.
    // Falls back to DartCryptoEngine automatically for v0 blobs.
    crypto: NativeCryptoEngine(),
    storage: SecureStorageService.instance,
  );

  late final AndroidMangaService _androidManga = AndroidMangaService(
    repo: _repo,
    openService: _openService,
    settingsService: _settingsService,
  );

  int? _currentFolderId;
  final List<VaultFolder> _folderStack = [];

  bool _loading = true;
  List<VaultFolder> _folders = [];
  List<VaultFile> _files = [];
  String _query = '';

  // Mobile-specific pagination - ultra lightweight
  static const int _pageSize =
      10; // Reduced from 20 to 10 for lighter memory usage
  int _currentPage = 0;
  bool _hasMoreFiles = true;
  bool _loadingMore = false;
  int _totalFileCount = 0;

  // Mobile UI state - minimal
  final Set<int> _selectedFileIds = {};
  final Set<int> _selectedFolderIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _checkPermissionsOnStartup();
  }

  /// Check permissions on app startup and show notification if needed
  Future<void> _checkPermissionsOnStartup() async {
    try {
      final hasPermissions = await _androidManga.hasAllStoragePermissions();
      if (!hasPermissions && mounted) {
        // Show a subtle notification that permissions are needed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Tap "Request Permissions" in menu for full storage access'),
                action: SnackBarAction(
                  label: 'Grant Now',
                  onPressed: _requestStoragePermissions,
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking permissions on startup: $e');
    }
  }

  Future<void> _refresh() async {
    debugPrint('DEBUG: Starting mobile refresh for folder $_currentFolderId');
    setState(() {
      _loading = true;
      _currentPage = 0;
      _files.clear();
      _folders.clear();
      _hasMoreFiles = true;
      _selectedFileIds.clear();
      _selectedFolderIds.clear();
      _selectionMode = false;
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
      debugPrint('DEBUG: Mobile refresh completed successfully');
    } catch (e) {
      debugPrint('DEBUG: Error during mobile refresh: $e');
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

  Widget _buildMobileBreadcrumbs() {
    if (_folderStack.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _folderStack.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return TextButton.icon(
              onPressed: () {
                setState(() {
                  _folderStack.clear();
                  _currentFolderId = null;
                });
                _refresh();
              },
              icon: const Icon(Icons.home, size: 16),
              label: const Text('Root'),
            );
          }

          final folder = _folderStack[index - 1];
          final isLast = index == _folderStack.length;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chevron_right, size: 16),
              TextButton(
                onPressed: isLast
                    ? null
                    : () {
                        setState(() {
                          _folderStack.removeRange(index, _folderStack.length);
                          _currentFolderId = _folderStack.isEmpty
                              ? null
                              : _folderStack.last.id;
                        });
                        _refresh();
                      },
                child: Text(
                  folder.name,
                  style: TextStyle(
                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<VaultFolder> get _visibleFolders {
    final q = _query.trim().toLowerCase();
    var items = _folders;
    if (q.isNotEmpty) {
      items = items.where((f) => f.name.toLowerCase().contains(q)).toList();
    }
    // No sorting - preserve original order from database
    return items;
  }

  List<VaultFile> get _visibleFiles {
    final q = _query.trim().toLowerCase();
    var items = _files;
    if (q.isNotEmpty) {
      items =
          items.where((f) => f.originalName.toLowerCase().contains(q)).toList();
    }
    // No sorting - preserve original order from database
    return items;
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
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoViewerScreen(file: file),
      ));
      return;
    }

    // For other files, try to open with system apps
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening ${file.originalName}...')),
    );
    try {
      await _openService.decryptToTempAndOpen(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Open failed: $e')),
      );
    }
  }

  // File and folder selection methods
  void _toggleFileSelection(VaultFile file) {
    setState(() {
      if (_selectedFileIds.contains(file.id)) {
        _selectedFileIds.remove(file.id);
      } else {
        _selectedFileIds.add(file.id);
      }
      _selectionMode =
          _selectedFileIds.isNotEmpty || _selectedFolderIds.isNotEmpty;
    });
  }

  void _toggleFolderSelection(VaultFolder folder) {
    setState(() {
      if (_selectedFolderIds.contains(folder.id)) {
        _selectedFolderIds.remove(folder.id);
      } else {
        _selectedFolderIds.add(folder.id);
      }
      _selectionMode =
          _selectedFileIds.isNotEmpty || _selectedFolderIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFileIds.clear();
      _selectedFolderIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedFileIds.isEmpty && _selectedFolderIds.isEmpty) return;

    final totalSelected = _selectedFileIds.length + _selectedFolderIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items'),
        content: Text(
            'Delete $totalSelected selected items?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // Delete selected files
      for (final fileId in _selectedFileIds) {
        await _repo.deleteFile(fileId: fileId);
      }

      // Delete selected folders
      for (final folderId in _selectedFolderIds) {
        await _repo.deleteFolderRecursive(folderId: folderId);
      }

      _clearSelection();
      await _refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $totalSelected items')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete items: $e')),
        );
      }
    }
  }

  void _showFileOptions(VaultFile file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open File'),
              onTap: () {
                Navigator.pop(context);
                _openFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: Text(
                  _selectedFileIds.contains(file.id) ? 'Deselect' : 'Select'),
              onTap: () {
                Navigator.pop(context);
                _toggleFileSelection(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete File'),
              onTap: () {
                Navigator.pop(context);
                _deleteFile(file);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderOptions(VaultFolder folder) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_stories),
              title: const Text('Open in Mihon'),
              subtitle: const Text('Create temp folder for manga reading'),
              onTap: () {
                Navigator.pop(context);
                _openFolderInMihon(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: Text(_selectedFolderIds.contains(folder.id)
                  ? 'Deselect'
                  : 'Select'),
              onTap: () {
                Navigator.pop(context);
                _toggleFolderSelection(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete Folder'),
              onTap: () {
                Navigator.pop(context);
                _deleteFolder(folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Open folder in Mihon manga reader
  Future<void> _openFolderInMihon(VaultFolder folder) async {
    if (!mounted) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MihonProgressDialog(
        androidManga: _androidManga,
        folder: folder,
        onComplete: (result) {
          Navigator.pop(context); // Close progress dialog
          if (result.success) {
            _showMihonSuccessDialog(folder.name, result.tempFolderPath,
                result.mihonDetected, result.mihonAppName);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to open in Mihon: ${result.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        onError: (error) {
          Navigator.pop(context); // Close progress dialog
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to open in Mihon: $error')),
            );
          }
        },
      ),
    );
  }

  void _showMihonSuccessDialog(String folderName, String tempPath,
      bool mihonDetected, String? mihonAppName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              mihonDetected ? Icons.check_circle : Icons.info,
              color: mihonDetected ? Colors.green : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(mihonDetected ? 'Mihon Launched' : 'Temp Folder Created'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mihonDetected
                  ? 'Successfully opened "$folderName" in ${mihonAppName ?? 'Mihon'}!'
                  : 'Images exported for "$folderName"',
            ),
            const SizedBox(height: 16),
            const Text('Temp folder location:',
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
              child: SelectableText(
                tempPath,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            if (!mihonDetected) ...[
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
                    Text('📱 Next Steps:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('1. Install Mihon from GitHub or F-Droid'),
                    Text('2. Open Mihon and navigate to the temp folder above'),
                    Text('3. Or use any manga reader app to open the folder'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              '🔒 Security: Tap "Clean Up" when done reading to remove temp files.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Reading'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              // Clean up temp folder
              final success =
                  await _androidManga.cleanupMangaReaderTemp(tempPath);

              if (mounted) {
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Temp folder cleaned up successfully!'
                        : 'Failed to clean up temp folder'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Clean Up'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFolder(VaultFolder folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
            'Delete "${folder.name}" and all its contents?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _repo.deleteFolderRecursive(folderId: folder.id);
        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${folder.name}"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete folder: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteFile(VaultFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text(
            'Delete "${file.originalName}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _repo.deleteFile(fileId: file.id);
        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${file.originalName}"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete file: $e')),
          );
        }
      }
    }
  }

  // Utility methods

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

  // Import methods - Mobile implementations

  /// Add new folder
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

  /// Add media files
  Future<void> _addMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Fixed for Android 15 compatibility
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        return;
      }

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select media: $e')),
      );
    }
  }

  /// Import folder (mobile version) - Enhanced to import entire folders with all content
  Future<void> _importFolder() async {
    try {
      // Show instruction dialog first
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Folder'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('To import an entire folder with all its content:'),
              SizedBox(height: 12),
              Text('1. Navigate to the folder you want to import'),
              Text(
                  '2. Select ALL files in that folder (use Ctrl+A or select all)'),
              Text('3. The app will organize them into a folder structure'),
              SizedBox(height: 12),
              Text(
                'Note: This will import all selected files and organize them by their folder structure.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;

      // Use file picker to select multiple files from folder
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        dialogTitle: 'Select ALL files from the folder you want to import',
      );

      if (result == null || result.files.isEmpty) return;

      if (!mounted) return;

      // Show progress dialog — uses ImportCoordinator (ISSUE-011 fix).
      // Build list of file paths from the picker result.
      final filePaths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();

      // Derive a folder name from the first file's parent directory.
      String folderName = 'Imported_Folder';
      if (filePaths.isNotEmpty) {
        final parts = filePaths.first.split(Platform.pathSeparator);
        if (parts.length > 1) {
          folderName = parts[parts.length - 2];
        }
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _MobileFolderImportDialog(
          importCoordinator: _importCoordinator,
          filePaths: filePaths,
          folderName: folderName,
          currentFolderId: _currentFolderId,
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

  /// Import ZIP file (supports encrypted .vault files from PC) - Enhanced for Android 15 with SAF
  Future<void> _importZip() async {
    try {
      final messenger = ScaffoldMessenger.of(context);

      // Pick ZIP or vault file with enhanced Android support
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select ZIP or Vault File',
        withData: false, // Don't load into memory initially
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;

      // Show loading while we prepare the file
      messenger
          .showSnackBar(const SnackBar(content: Text('Preparing file...')));

      try {
        // Handle regular ZIP import with SAF for Android 15+ compatibility
        if (!mounted) return;
        messenger.hideCurrentSnackBar();

        final passwordController = TextEditingController();
        final password = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import ZIP'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selected file: ${pickedFile.name}'),
                const SizedBox(height: 8),
                const Text('Note: Using SAF for Android 15+ compatibility'),
                const SizedBox(height: 16),
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
                onPressed: () =>
                    Navigator.pop(context, passwordController.text),
                child: const Text('Import'),
              ),
            ],
          ),
        );

        if (password == null) return; // User cancelled

        if (!mounted) return;
        messenger.showSnackBar(
            const SnackBar(content: Text('Importing ZIP via SAF...')));

        try {
          // Try SAF approach first (Android 15+ compatible)
          if (Platform.isAndroid && pickedFile.path != null) {
            final zipFilePath = pickedFile.path!;

            if (!mounted) return;
            messenger.hideCurrentSnackBar();

            // Show ImportCoordinator progress dialog (FEAT-003).
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => _MobileZipImportDialog(
                importCoordinator: _importCoordinator,
                zipPath: zipFilePath,
                password: password.trim(),
                destinationFolderId: _currentFolderId,
                onComplete: () {
                  Navigator.pop(context);
                  _refresh();
                },
              ),
            );
            return;
          }

          // Fallback to traditional approach for other platforms or if SAF fails
          throw Exception('SAF not available, using fallback method');
        } catch (safError) {
          debugPrint('SAF import failed, trying fallback: $safError');

          // Fallback to enhanced file handling approach
          String? workingFilePath;

          if (pickedFile.bytes != null && pickedFile.bytes!.isNotEmpty) {
            // Use bytes if available (most reliable on Android)
            final appDir = await getApplicationCacheDirectory();
            final importId =
                Random().nextInt(999999).toString().padLeft(6, '0');
            final tempDir =
                Directory(path.join(appDir.path, 'local_vault_zip_$importId'));
            await tempDir.create(recursive: true);
            final tempFile = File(path.join(tempDir.path, pickedFile.name));
            await tempFile.writeAsBytes(pickedFile.bytes!);
            workingFilePath = tempFile.path;
            debugPrint(
                'Using file bytes approach: ${pickedFile.bytes!.length} bytes');
          } else {
            final filePath = pickedFile.path;
            if (filePath != null) {
              // Try direct path access
              final sourceFile = File(filePath);
              if (await sourceFile.exists()) {
                workingFilePath = filePath;
                debugPrint('Using direct path approach: $filePath');
              } else {
                // Copy to app directory for reliable access
                final appDir = await getApplicationCacheDirectory();
                final importId =
                    Random().nextInt(999999).toString().padLeft(6, '0');
                final tempDir = Directory(
                    path.join(appDir.path, 'local_vault_zip_$importId'));
                await tempDir.create(recursive: true);
                final tempFile = File(path.join(tempDir.path, pickedFile.name));

                // Try to read and copy the file
                try {
                  final bytes = await sourceFile.readAsBytes();
                  await tempFile.writeAsBytes(bytes);
                  workingFilePath = tempFile.path;
                  debugPrint(
                      'Using copy approach: copied ${bytes.length} bytes');
                } catch (e) {
                  debugPrint('Failed to copy file: $e');
                  throw Exception(
                      'Unable to access the selected file. Please try again or select a different file.');
                }
              }
            } else {
              throw Exception('No file path or data available from picker');
            }
          }

          // Import using ImportCoordinator (FEAT-003: routes through
          // JobRunner + repo.addMedia so totalBytesUsed is always updated).
          String? importError;
          int importedFiles = 0;

          try {
            await for (final progress in _importCoordinator.importZip(
              workingFilePath,
              _currentFolderId,
              password: password.trim(),
              onStatus: (msg) {
                // Status updates logged; no inline snackbar during import.
                debugPrint('[ZIP import] $msg');
              },
            )) {
              importedFiles = progress.completedFiles;
            }
          } catch (e) {
            importError = e.toString();
          }

          if (!mounted) return;
          messenger.hideCurrentSnackBar();

          if (importError == null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                    'Successfully imported $importedFiles files via ImportCoordinator'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Import failed: $importError'),
                backgroundColor: Colors.red,
              ),
            );
          }

          await _refresh();
        }
      } catch (e) {
        if (!mounted) return;
        messenger.hideCurrentSnackBar();

        String errorMessage = e.toString();

        messenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select or import file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Import Android vault (legacy format)
  // Removed: _importAndroidVault - Android vault import has been removed
  // Use ZIP import instead

  /// Show temp folder settings for manga reader integration
  Future<void> _showTempFolderSettings() async {
    try {
      // Get current temp folder location
      final currentLocation =
          await _androidManga.getCurrentTempFolderLocation();

      // Get available options
      final options = await _androidManga.getAvailableTempFolderLocations();

      if (!mounted) return;

      final selectedOption = await showDialog<TempFolderOption>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Manga Reader Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Choose where to create temp folders for manga reading:'),
              const SizedBox(height: 16),
              Text(
                'Current: $currentLocation',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Available locations:'),
              const SizedBox(height: 8),
              ...options.map((option) => ListTile(
                    title: Text(option.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.path,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12)),
                        Text(option.description,
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    leading: option.isRecommended
                        ? const Icon(Icons.star, color: Colors.orange)
                        : const Icon(Icons.folder),
                    onTap: () => Navigator.pop(context, option),
                  )),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
          ],
        ),
      );

      if (selectedOption == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting temp folder location...')),
      );

      final success =
          await _androidManga.setCustomTempFolderLocation(selectedOption.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Temp folder set to: ${selectedOption.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to set temp folder location'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settings error: $e')),
      );
    }
  }

  /// Show storage permissions dialog and request permissions
  Future<void> _requestStoragePermissions() async {
    try {
      final result = await _androidManga.requestAllStoragePermissions();

      if (!mounted) return;

      if (result.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show permission explanation dialog
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Storage Permissions Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.message),
                const SizedBox(height: 16),
                const Text(
                  'This app needs full storage access to:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• Import/export manga collections'),
                const Text('• Create temp folders for manga readers'),
                const Text('• Access files in Downloads folder'),
                const Text('• Save files to custom locations'),
                if (result.needsSettings) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Please enable "All files access" in Settings.',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              if (result.needsSettings)
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                )
              else
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context, false);
                    await _requestStoragePermissions(); // Retry
                  },
                  child: const Text('Try Again'),
                ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission error: $e')),
      );
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
          title: Text(
              _folderStack.isEmpty ? 'Local Vault' : _folderStack.last.name),
          leading: _selectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                )
              : null,
          actions: [
            if (_selectionMode) ...[
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteSelectedItems,
              ),
              IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: () {
                  setState(() {
                    if (_selectedFileIds.length == _visibleFiles.length &&
                        _selectedFolderIds.length == _visibleFolders.length) {
                      // Deselect all
                      _clearSelection();
                    } else {
                      // Select all
                      _selectedFileIds.clear();
                      _selectedFolderIds.clear();
                      _selectedFileIds.addAll(_visibleFiles.map((f) => f.id));
                      _selectedFolderIds
                          .addAll(_visibleFolders.map((f) => f.id));
                    }
                  });
                },
              ),
            ] else ...[
              // Top bar buttons for common actions
              IconButton(
                icon: const Icon(Icons.cleaning_services),
                onPressed: _clearCacheQuick,
                tooltip: 'Clear Cache',
              ),
              IconButton(
                icon: const Icon(Icons.create_new_folder),
                onPressed: _addFolder,
                tooltip: 'Add Folder',
              ),
              IconButton(
                icon: const Icon(Icons.add_photo_alternate),
                onPressed: _addMedia,
                tooltip: 'Add Media',
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => GlobalSearchScreen(repo: _repo)),
                  );
                },
                tooltip: 'Search',
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'import_folder':
                      await _importFolder();
                      break;
                    case 'import_zip':
                      await _importZip();
                      break;
                    case 'export_all':
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Export not yet implemented on mobile')),
                      );
                      break;
                    case 'temp_folder_settings':
                      await _showTempFolderSettings();
                      break;
                    case 'request_permissions':
                      await _requestStoragePermissions();
                      break;
                    case 'settings':
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                      break;
                    case 'lock':
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthGate()),
                        (_) => false,
                      );
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'import_folder',
                    child: ListTile(
                      leading: Icon(Icons.folder),
                      title: Text('Import Folder'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'import_zip',
                    child: ListTile(
                      leading: Icon(Icons.archive),
                      title: Text('Import ZIP'),
                      subtitle: Text('Password-protected or plain ZIP'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export_all',
                    child: ListTile(
                      leading: Icon(Icons.upload),
                      title: Text('Export All'),
                      subtitle: Text('Coming soon'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'temp_folder_settings',
                    child: ListTile(
                      leading: Icon(Icons.folder_open),
                      title: Text('Manga Reader Settings'),
                      subtitle: Text('Configure temp folder location'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'request_permissions',
                    child: ListTile(
                      leading: Icon(Icons.security),
                      title: Text('Request Permissions'),
                      subtitle: Text('Grant full storage access'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'lock',
                    child: ListTile(
                      leading: Icon(Icons.lock),
                      title: Text('Lock Vault'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  slivers: [
                    // Breadcrumbs
                    if (_folderStack.isNotEmpty)
                      SliverToBoxAdapter(child: _buildMobileBreadcrumbs()),

                    // Search filter
                    if (_query.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Chip(
                            label: Text('Filter: "$_query"'),
                            onDeleted: () => setState(() => _query = ''),
                          ),
                        ),
                      ),

                    // Folders - Lightweight list
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final folder = _visibleFolders[index];
                          final isSelected =
                              _selectedFolderIds.contains(folder.id);
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            child: ListTile(
                              dense: true,
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_selectionMode)
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (_) =>
                                          _toggleFolderSelection(folder),
                                    )
                                  else
                                    const Icon(Icons.folder, size: 20),
                                ],
                              ),
                              title: Text(
                                folder.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                              trailing: _selectionMode
                                  ? null
                                  : IconButton(
                                      icon:
                                          const Icon(Icons.more_vert, size: 16),
                                      onPressed: () =>
                                          _showFolderOptions(folder),
                                    ),
                              onTap: _selectionMode
                                  ? () => _toggleFolderSelection(folder)
                                  : () => _openFolder(folder),
                              onLongPress: _selectionMode
                                  ? null
                                  : () => _toggleFolderSelection(folder),
                            ),
                          );
                        },
                        childCount: _visibleFolders.length,
                      ),
                    ),

                    // Files - Lightweight list view optimized for Android
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final file = _visibleFiles[index];
                          final isImg = isImageFileName(file.originalName);
                          final isSelected = _selectedFileIds.contains(file.id);
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            child: ListTile(
                              dense: true, // Compact layout for mobile
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_selectionMode)
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (_) =>
                                          _toggleFileSelection(file),
                                    )
                                  else
                                    Icon(
                                      isImg
                                          ? Icons.image
                                          : Icons.insert_drive_file,
                                      size: 20, // Smaller icons for performance
                                    ),
                                ],
                              ),
                              title: Text(
                                file.originalName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                formatBytes(file.byteSize),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: _selectionMode
                                  ? null
                                  : IconButton(
                                      icon:
                                          const Icon(Icons.more_vert, size: 16),
                                      onPressed: () => _showFileOptions(file),
                                    ),
                              onTap: _selectionMode
                                  ? () => _toggleFileSelection(file)
                                  : () => _openFile(file),
                              onLongPress: _selectionMode
                                  ? null
                                  : () => _toggleFileSelection(file),
                            ),
                          );
                        },
                        childCount: _visibleFiles.length,
                      ),
                    ),

                    // Load more button
                    if (_hasMoreFiles && !_loading)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
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

                    // Empty state
                    if (_visibleFolders.isEmpty &&
                        _visibleFiles.isEmpty &&
                        !_loading)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.folder_open,
                                  size: 64,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              const SizedBox(height: 16),
                              const Text('No items found'),
                              const SizedBox(height: 8),
                              Text(
                                'Import an encrypted vault file to get started',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                            ],
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

// Folder import progress dialog for mobile
class _FolderImportProgressDialog extends StatefulWidget {
  final List<PlatformFile> files;
  final VaultRepository repo;
  final int? currentFolderId;
  final VoidCallback onComplete;

  const _FolderImportProgressDialog({
    required this.files,
    required this.repo,
    required this.currentFolderId,
    required this.onComplete,
  });

  @override
  State<_FolderImportProgressDialog> createState() =>
      _FolderImportProgressDialogState();
}

class _FolderImportProgressDialogState
    extends State<_FolderImportProgressDialog> {
  String _status = 'Starting import...';
  int _processed = 0;
  int _imported = 0;
  bool _isComplete = false;
  bool _pendingRebuild = false;

  // Coalesce rebuilds into at most one per frame so the per-file progress
  // updates do not thrash the UI isolate. This dialog imports via
  // VaultRepository.addMedia directly and has no byte totals to show.
  void _scheduleRebuild() {
    if (_pendingRebuild) return;
    _pendingRebuild = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
      _pendingRebuild = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _performImport();
  }

  Future<void> _performImport() async {
    try {
      final totalFiles = widget.files.length;
      setState(() => _status = 'Analyzing $totalFiles files...');

      // Group files by their directory structure
      final Map<String, List<PlatformFile>> folderGroups = {};

      for (final file in widget.files) {
        // Extract folder name from file path or use a default
        String folderName = 'Imported_Folder';

        if (file.path != null) {
          final pathParts = file.path!.split(Platform.pathSeparator);
          if (pathParts.length > 1) {
            // Use the parent directory name
            folderName = pathParts[pathParts.length - 2];
          }
        }

        folderGroups.putIfAbsent(folderName, () => []).add(file);
      }

      setState(() => _status = 'Creating folder structure...');

      // Create folders and import files
      for (final entry in folderGroups.entries) {
        final folderName = entry.key;
        final files = entry.value;

        // Create folder for this group
        final folder = await widget.repo.createFolder(
          name: folderName,
          parentId: widget.currentFolderId,
        );

        setState(() => _status = 'Importing files to "$folderName"...');

        // Process files in smaller batches to prevent UI blocking
        const batchSize = 2; // Process 2 files at a time
        for (int i = 0; i < files.length; i += batchSize) {
          final batch = files.skip(i).take(batchSize).toList();

          // Process batch
          for (final file in batch) {
            try {
              await widget.repo.addMedia(
                originalName: file.name,
                parentFolderId: folder.id,
                sourcePath: file.path,
                bytes: file.bytes,
                mimeType: file.extension,
              );
              _imported++;
            } catch (e) {
              debugPrint('Failed to import ${file.name}: $e');
            }

            _processed++;

            // Coalesce: schedule at most one rebuild per frame instead of
            // calling setState for every file.
            _status = 'Imported ${file.name} ($_processed/$totalFiles)';
            _scheduleRebuild();
          }

          // Yield to UI thread after each batch to prevent blocking
          await Future.delayed(const Duration(milliseconds: 10));

          // Allow UI to update (coalesced).
          if (mounted) {
            _scheduleRebuild();
          }
        }
      }

      setState(() {
        _status =
            'Import completed! Imported $_imported files into ${folderGroups.length} folders.';
        _isComplete = true;
      });

      // Show success message in the dialog itself, no need for snackbar
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Import failed: $e';
          _isComplete = true;
        });

        await Future.delayed(const Duration(seconds: 2));

        // Don't show snackbar to avoid BuildContext issues
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
          Text(
            _status,
            textAlign: TextAlign.center,
          ),
          if (_processed > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _processed / widget.files.length,
            ),
            const SizedBox(height: 4),
            Text(
              '$_processed / ${widget.files.length} files processed',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
      actions: _isComplete
          ? [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ]
          : null,
    );
  }
}

// _EnhancedFolderImportDialog removed — it used the deprecated EnhancedVaultRepository.
// All folder imports now route through _MobileFolderImportDialog via ImportCoordinator.

// _ZipImportProgressDialog removed — it used the deprecated SafZipImportService.
// All ZIP imports now route through _MobileZipImportDialog via ImportCoordinator.

/// Mihon progress dialog for Android
class _MihonProgressDialog extends StatefulWidget {
  const _MihonProgressDialog({
    required this.androidManga,
    required this.folder,
    required this.onComplete,
    required this.onError,
  });

  final AndroidMangaService androidManga;
  final VaultFolder folder;
  final Function(AndroidMangaReaderResult) onComplete;
  final Function(String) onError;

  @override
  State<_MihonProgressDialog> createState() => _MihonProgressDialogState();
}

class _MihonProgressDialogState extends State<_MihonProgressDialog> {
  String _currentStatus = 'Preparing export...';
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _startExport();
  }

  Future<void> _startExport() async {
    try {
      final result = await widget.androidManga.openInMangaReader(
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
        title: Text(_isComplete ? 'Export Complete' : 'Opening in Mihon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isComplete) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 24),
              Text(_currentStatus, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              Text(
                'Decrypting and exporting images...',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ] else ...[
              const Center(
                  child:
                      Icon(Icons.check_circle, color: Colors.green, size: 48)),
              const SizedBox(height: 16),
              Text(_currentStatus),
            ],
          ],
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
// ZIP import dialog backed by ImportCoordinator (FEAT-003)
// ---------------------------------------------------------------------------

class _MobileZipImportDialog extends StatefulWidget {
  const _MobileZipImportDialog({
    required this.importCoordinator,
    required this.zipPath,
    required this.password,
    required this.destinationFolderId,
    required this.onComplete,
  });

  final ImportCoordinator importCoordinator;
  final String zipPath;
  final String password;
  final int? destinationFolderId;
  final VoidCallback onComplete;

  @override
  State<_MobileZipImportDialog> createState() => _MobileZipImportDialogState();
}

class _MobileZipImportDialogState extends State<_MobileZipImportDialog> {
  String _statusText = 'Starting ZIP import…';
  int _latestCompleted = 0;
  int _latestTotal = 0;
  int _latestProcessedBytes = 0;
  int _latestTotalBytes = 0;
  bool _isComplete = false;
  String? _errorText;
  bool _pendingRebuild = false;

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  // Coalesce progress events into at most one rebuild per frame so a burst of
  // ImportProgress yields does not thrash the UI isolate. The bar is
  // indeterminate during the ZIP pre-count phase (total is 0 until the first
  // entry is processed).
  void _onProgress(ImportProgress p) {
    _latestCompleted = p.completedFiles;
    _latestTotal = p.totalFiles;
    _latestProcessedBytes = p.processedBytes;
    _latestTotalBytes = p.totalBytes;
    _scheduleRebuild();
  }

  void _onStatus(String msg) {
    _statusText = msg;
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    if (_pendingRebuild) return;
    _pendingRebuild = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
      _pendingRebuild = false;
    });
  }

  Future<void> _startImport() async {
    try {
      await for (final progress in widget.importCoordinator.importZip(
        widget.zipPath,
        widget.destinationFolderId,
        password: widget.password,
        onStatus: _onStatus,
      )) {
        if (!mounted) break;
        _onProgress(progress);
      }
      if (mounted) {
        setState(() {
          _isComplete = true;
          _statusText = 'Import complete! $_latestCompleted files imported.';
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

  static String _fmtMb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final fraction = _latestTotal > 0 ? _latestCompleted / _latestTotal : null;
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
// Mobile folder import dialog using ImportCoordinator (ISSUE-011 fix)
// ---------------------------------------------------------------------------

class _MobileFolderImportDialog extends StatefulWidget {
  const _MobileFolderImportDialog({
    required this.importCoordinator,
    required this.filePaths,
    required this.folderName,
    required this.currentFolderId,
    required this.onComplete,
  });

  final ImportCoordinator importCoordinator;
  final List<String> filePaths;
  final String folderName;
  final int? currentFolderId;
  final VoidCallback onComplete;

  @override
  State<_MobileFolderImportDialog> createState() =>
      _MobileFolderImportDialogState();
}

class _MobileFolderImportDialogState extends State<_MobileFolderImportDialog> {
  String _statusText = 'Starting import...';
  int _completedFiles = 0;
  int _totalFiles = 0;
  bool _isComplete = false;
  String? _errorText;
  bool _pendingRebuild = false;

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  // Coalesce progress events into at most one rebuild per frame so a burst of
  // ImportProgress yields does not thrash the UI isolate. No byte progress is
  // shown on this dialog (this path imports a flat file list; the file count
  // is the meaningful signal).
  void _onProgress(ImportProgress p) {
    _completedFiles = p.completedFiles;
    _totalFiles = p.totalFiles;
    _scheduleRebuild();
  }

  void _onStatus(String msg) {
    _statusText = msg;
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    if (_pendingRebuild) return;
    _pendingRebuild = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
      _pendingRebuild = false;
    });
  }

  Future<void> _startImport() async {
    try {
      await for (final progress in widget.importCoordinator.importFileList(
        widget.filePaths,
        widget.currentFolderId,
        folderName: widget.folderName,
        onStatus: _onStatus,
      )) {
        if (!mounted) break;
        _onProgress(progress);
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
        title: Text(_isComplete ? 'Import Complete' : 'Importing Files'),
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
