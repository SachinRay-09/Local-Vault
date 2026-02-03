import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/vault_file.dart';
import '../../models/vault_folder.dart';
import '../../services/android_manga_service.dart';
import '../../services/file_crypto_service.dart';
import '../../services/file_open_service.dart';
import '../../services/secure_storage_service.dart';
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
  final VaultRepository _repo = VaultRepository(
    crypto: const FileCryptoService(),
    secureStorage: SecureStorageService.instance,
  );

  late final VaultOpenService _openService = VaultOpenService(
    crypto: const FileCryptoService(),
    secureStorage: SecureStorageService.instance,
    opener: FileOpenService(),
  );

  late final AndroidMangaService _androidManga = AndroidMangaService(
    repo: _repo,
    openService: _openService,
  );

  int? _currentFolderId;
  final List<VaultFolder> _folderStack = [];

  bool _loading = true;
  List<VaultFolder> _folders = [];
  List<VaultFile> _files = [];
  String _query = '';

  // Mobile-specific pagination - ultra lightweight
  static const int _pageSize = 10; // Reduced from 20 to 10 for lighter memory usage
  int _currentPage = 0;
  bool _hasMoreFiles = true;
  bool _loadingMore = false;
  int _totalFileCount = 0;

  // Mobile UI state - minimal
  final Set<int> _selectedFileIds = {};
  final Set<int> _selectedFolderIds = {};

  @override
  void initState() {
    super.initState();
    _refresh();
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
      _hasMoreFiles = moreFiles.length >= _pageSize && _files.length < _totalFileCount;
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
                onPressed: isLast ? null : () {
                  setState(() {
                    _folderStack.removeRange(index, _folderStack.length);
                    _currentFolderId = _folderStack.isEmpty ? null : _folderStack.last.id;
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
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  List<VaultFile> get _visibleFiles {
    final q = _query.trim().toLowerCase();
    var items = _files;
    if (q.isNotEmpty) {
      items = items.where((f) => f.originalName.toLowerCase().contains(q)).toList();
    }
    items.sort((a, b) => a.originalName.toLowerCase().compareTo(b.originalName.toLowerCase()));
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

  Future<void> _importAndroidVault() async {
    try {
      // Pick vault file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['vault'],
        dialogTitle: 'Select Android Vault File',
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final vaultFilePath = result.files.first.path;
      if (vaultFilePath == null) {
        throw Exception('Invalid file path');
      }

      // Show password dialog
      final password = await _showPasswordDialog();
      if (password == null) {
        return; // User cancelled
      }

      // Show import progress dialog
      _showImportProgressDialog(vaultFilePath, password);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select vault file: $e')),
      );
    }
  }

  Future<String?> _showPasswordDialog() async {
    String? password;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Vault Password'),
        content: TextField(
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => password = value,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, password),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showImportProgressDialog(String vaultFilePath, String password) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ImportProgressScreen(
          vaultFilePath: vaultFilePath,
          password: password,
          androidManga: _androidManga,
          onComplete: () {
            Navigator.of(context).pop(); // Pop the import screen
            _refresh(); // Refresh the main screen
          },
        ),
      ),
    );
  }

  Future<void> _exportForAndroid(VaultFolder folder) async {
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      messenger.showSnackBar(
        SnackBar(content: Text('Exporting "${folder.name}" for Android...')),
      );

      final result = await _androidManga.exportFolderForAndroid(folder);
      
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      
      if (result.success) {
        _showAndroidExportSuccessDialog(result);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Export failed: ${result.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _showAndroidExportSuccessDialog(AndroidExportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.android, color: Colors.green),
            SizedBox(width: 8),
            Text('Android Export Ready'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.message),
            const SizedBox(height: 16),
            const Text('Export file created at:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                result.exportPath,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '📱 Next steps:\n'
              '1. Transfer this file to your Android device\n'
              '2. Open Local Vault on Android\n'
              '3. Import the vault file\n'
              '4. Enter your password to decrypt',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _androidManga.shareVaultFile(result.exportPath);
            },
            child: const Text('Share File'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInMangaReader(VaultFolder folder) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      messenger.showSnackBar(
        SnackBar(content: Text('Preparing "${folder.name}" for manga reader...')),
      );

      final result = await _androidManga.openInMangaReader(folder);
      
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      
      // Use callback to avoid BuildContext across async gaps
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMangaReaderDialog(folder.name, result);
        }
      });
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to open in manga reader: $e')),
      );
    }
  }

  void _showMangaReaderDialog(String folderName, AndroidMangaReaderResult result) async {
    // Check if Mihon is installed
    final mihonInstalled = await _androidManga.isMihonInstalled();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.info,
              color: result.success ? Colors.green : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(result.success ? 'Ready to Read' : 'Manual Setup Required'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message),
              
              if (result.success) ...[
                const SizedBox(height: 16),
                
                // Mihon detection status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: mihonInstalled ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: mihonInstalled ? Colors.green : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        mihonInstalled ? Icons.check_circle : Icons.warning,
                        color: mihonInstalled ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mihonInstalled 
                              ? '✅ Mihon detected on your device!'
                              : '⚠️ Mihon not found - install from GitHub',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: mihonInstalled ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Temp folder path display
                const Text('📁 Temp folder location:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        result.tempFolderPath,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Copy this path to open in your manga reader app',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                const Text('📚 Recommended manga readers:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._androidManga.getRecommendedMangaReaders().map(
                  (reader) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          reader.isPriority ? Icons.star : Icons.circle,
                          size: 12,
                          color: reader.isPriority ? Colors.amber : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${reader.name} - ${reader.description}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: reader.isPriority ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🔒 Security: Click "Clean Up" when finished reading to remove temp files and protect your data.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (result.success) ...[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Keep Reading'),
            ),
            if (mihonInstalled)
              FilledButton.icon(
                onPressed: () => _handleMihonLaunch(dialogContext, result.tempFolderPath),
                icon: const Icon(Icons.auto_stories),
                label: const Text('Open in Mihon'),
              )
            else
              FilledButton(
                onPressed: () => _handleCleanup(dialogContext, result.tempFolderPath),
                child: const Text('Clean Up'),
              ),
          ] else ...[
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ],
      ),
    );
  }

  void _handleMihonLaunch(BuildContext dialogContext, String tempFolderPath) async {
    await _androidManga.launchMihon(tempFolderPath);
    // Use post frame callback to ensure safe context usage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
      }
    });
  }

  void _handleCleanup(BuildContext dialogContext, String tempFolderPath) async {
    await _androidManga.cleanupMangaReaderTemp(tempFolderPath);
    // Use post frame callback to ensure safe context usage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
        // Additional callback for snackbar
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Temp files cleaned up successfully!')),
            );
          }
        });
      }
    });
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
              title: const Text('Open in Manga Reader'),
              subtitle: const Text('Export to temp folder and open with external app'),
              onTap: () {
                Navigator.pop(context);
                _openInMangaReader(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.android),
              title: const Text('Export for Android'),
              subtitle: const Text('Create encrypted file for transfer'),
              onTap: () {
                Navigator.pop(context);
                _exportForAndroid(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Open Folder'),
              onTap: () {
                Navigator.pop(context);
                _openFolder(folder);
              },
            ),
          ],
        ),
      ),
    );
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
          title: Text(_folderStack.isEmpty ? 'Local Vault' : _folderStack.last.name),
          actions: [
            // Removed grid/list toggle to keep UI simple and lightweight
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'import_android':
                    await _importAndroidVault();
                    break;
                  case 'search':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => GlobalSearchScreen(repo: _repo)),
                    );
                    break;
                  case 'settings':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
                  value: 'import_android',
                  child: ListTile(
                    leading: Icon(Icons.android),
                    title: Text('Import Android Vault'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'search',
                  child: ListTile(
                    leading: Icon(Icons.search),
                    title: Text('Search'),
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
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.folder, size: 20),
                              title: Text(
                                folder.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onPressed: () => _showFolderOptions(folder),
                              ),
                              onTap: () => _openFolder(folder),
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
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: ListTile(
                              dense: true, // Compact layout for mobile
                              leading: Icon(
                                isImg ? Icons.image : Icons.insert_drive_file,
                                size: 20, // Smaller icons for performance
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
                              onTap: () => _openFile(file),
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
                                    label: Text('Load more (${_totalFileCount - _files.length} remaining)'),
                                  ),
                          ),
                        ),
                      ),
                    
                    // Empty state
                    if (_visibleFolders.isEmpty && _visibleFiles.isEmpty && !_loading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.folder_open, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No items found'),
                              SizedBox(height: 8),
                              Text(
                                'Import an Android vault file to get started',
                                style: TextStyle(color: Colors.grey),
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

// Separate screen for import progress to avoid BuildContext async issues
class _ImportProgressScreen extends StatefulWidget {
  final String vaultFilePath;
  final String password;
  final AndroidMangaService androidManga;
  final VoidCallback onComplete;

  const _ImportProgressScreen({
    required this.vaultFilePath,
    required this.password,
    required this.androidManga,
    required this.onComplete,
  });

  @override
  State<_ImportProgressScreen> createState() => _ImportProgressScreenState();
}

class _ImportProgressScreenState extends State<_ImportProgressScreen> {
  String _status = 'Starting import...';
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _performImport();
  }

  Future<void> _performImport() async {
    try {
      setState(() => _status = 'Validating vault file...');
      
      final result = await widget.androidManga.importAndroidVault(
        vaultFilePath: widget.vaultFilePath,
        password: widget.password,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _status = progress);
          }
        },
      );

      if (!mounted) return;

      if (result.success) {
        setState(() => _status = 'Import completed successfully!');
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported ${result.filesImported} files'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() => _isComplete = true);
          widget.onComplete();
        }
      } else {
        setState(() => _status = 'Import failed: ${result.message}');
        await Future.delayed(const Duration(seconds: 2));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Import failed: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isComplete = true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Import failed: $e');
        await Future.delayed(const Duration(seconds: 2));
        
        // Use post frame callback to avoid BuildContext async gap
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Import failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
        setState(() => _isComplete = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importing Vault'),
        automaticallyImplyLeading: _isComplete,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isComplete) const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (_isComplete) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}