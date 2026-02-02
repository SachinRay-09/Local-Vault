import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/vault_file.dart';
import '../../services/file_crypto_service.dart';
import '../../services/file_open_service.dart';
import '../../services/secure_storage_service.dart';
import '../../services/vault_open_service.dart';
import '../../services/vault_repository.dart';
import '../../utils/vault_format.dart';

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.file,
    this.allFiles,
  });

  final VaultFile file;
  final List<VaultFile>? allFiles;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final VaultOpenService _openService = VaultOpenService(
    crypto: const FileCryptoService(),
    secureStorage: SecureStorageService.instance,
    opener: FileOpenService(),
  );

  late final VaultRepository _repo = VaultRepository(
    crypto: const FileCryptoService(),
    secureStorage: SecureStorageService.instance,
  );

  PageController? _pageController;
  List<VaultFile> _imageFiles = [];
  int _currentIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializeImages();
  }

  Future<void> _initializeImages() async {
    // Get all image files in the same folder
    List<VaultFile> allFiles = widget.allFiles ?? [];
    
    if (allFiles.isEmpty) {
      // Load files from the same parent folder
      allFiles = await _repo.listFiles(parentId: widget.file.parentFolderId);
    }

    // Filter only image files
    _imageFiles = allFiles.where((f) => isImageFileName(f.originalName)).toList();
    
    // Find current file index
    _currentIndex = _imageFiles.indexWhere((f) => f.id == widget.file.id);
    if (_currentIndex == -1) {
      _currentIndex = 0;
      _imageFiles = [widget.file];
    }

    _pageController = PageController(initialPage: _currentIndex);
    
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentFile = _imageFiles[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentFile.originalName,
              style: const TextStyle(fontSize: 16),
            ),
            if (_imageFiles.length > 1)
              Text(
                '${_currentIndex + 1} of ${_imageFiles.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open with system app',
            onPressed: () => _openService.decryptToTempAndOpen(currentFile),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _imageFiles.length,
            itemBuilder: (context, index) {
              final file = _imageFiles[index];
              return _ImagePage(
                file: file,
                openService: _openService,
              );
            },
          ),
          
          // Navigation arrows for desktop/large screens
          if (_imageFiles.length > 1) ...[
            // Left arrow
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _currentIndex > 0 ? () {
                    _pageController?.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } : null,
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            
            // Right arrow
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _currentIndex < _imageFiles.length - 1 ? () {
                    _pageController?.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } : null,
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImagePage extends StatefulWidget {
  const _ImagePage({
    required this.file,
    required this.openService,
  });

  final VaultFile file;
  final VaultOpenService openService;

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage> with AutomaticKeepAliveClientMixin {
  Future<File>? _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.openService.decryptToCachedTempFile(widget.file);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return FutureBuilder<File>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Decrypting image...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }
        
        final file = snapshot.data!;
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Center(
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not render this image.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

