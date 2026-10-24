import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/vault_file.dart';
import '../../services/file_crypto_service.dart';
import '../../services/file_open_service.dart';
import '../../services/secure_storage_service.dart';
import '../../services/vault_open_service.dart';
import '../../utils/vault_format.dart';

class OptimizedImageViewer extends StatefulWidget {
  const OptimizedImageViewer({
    super.key,
    required this.file,
    required this.allFiles,
  });

  final VaultFile file;
  final List<VaultFile> allFiles;

  @override
  State<OptimizedImageViewer> createState() => _OptimizedImageViewerState();
}

class _OptimizedImageViewerState extends State<OptimizedImageViewer>
    with TickerProviderStateMixin {
  late final VaultOpenService _openService = VaultOpenService(
    crypto: const FileCryptoService(),
    secureStorage: SecureStorageService.instance,
    opener: FileOpenService(),
  );

  late PageController _pageController;
  List<VaultFile> _imageFiles = [];
  int _currentIndex = 0;
  bool _loading = true;

  // Performance optimizations
  late AnimationController _fadeController;

  // Preloading cache
  final Map<int, File> _imageCache = {};
  final Set<int> _preloadingIndices = {};

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _initializeImages();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();

    // EMERGENCY: Aggressive memory cleanup
    _imageCache.clear();
    _preloadingIndices.clear();
    _imageFiles.clear();

    // Clear image cache to prevent memory leaks
    PaintingBinding.instance.imageCache.clear();

    super.dispose();
  }

  Future<void> _initializeImages() async {
    // Filter only image files
    _imageFiles =
        widget.allFiles.where((f) => isImageFileName(f.originalName)).toList();

    // Find current file index
    _currentIndex = _imageFiles.indexWhere((f) => f.id == widget.file.id);
    if (_currentIndex == -1) {
      _currentIndex = 0;
      _imageFiles = [widget.file];
    }

    _pageController = PageController(initialPage: _currentIndex);

    setState(() => _loading = false);

    // Start preloading current and adjacent images
    _preloadImages();
    _fadeController.forward();
  }

  void _preloadImages() {
    // Preload current, next, and previous images
    final indicesToPreload = [
      _currentIndex,
      if (_currentIndex > 0) _currentIndex - 1,
      if (_currentIndex < _imageFiles.length - 1) _currentIndex + 1,
    ];

    for (final index in indicesToPreload) {
      _preloadImage(index);
    }
  }

  Future<void> _preloadImage(int index) async {
    if (index < 0 || index >= _imageFiles.length) return;
    if (_imageCache.containsKey(index) || _preloadingIndices.contains(index)) {
      return;
    }

    _preloadingIndices.add(index);
    try {
      final file =
          await _openService.decryptToCachedTempFile(_imageFiles[index]);
      if (mounted) {
        _imageCache[index] = file;
      }
    } catch (e) {
      debugPrint('Failed to preload image at index $index: $e');
    } finally {
      _preloadingIndices.remove(index);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);

    // Preload adjacent images
    _preloadImage(index - 1);
    _preloadImage(index + 1);

    // Clean up distant images to save memory
    _cleanupDistantImages(index);

    // Provide haptic feedback
    HapticFeedback.selectionClick();
  }

  void _cleanupDistantImages(int currentIndex) {
    final keysToRemove = _imageCache.keys
        .where((key) => (key - currentIndex).abs() > 2)
        .toList();

    for (final key in keysToRemove) {
      final file = _imageCache.remove(key);
      if (file != null) {
        // Evict decoded bitmap from Flutter's image codec cache.
        PaintingBinding.instance.imageCache.evict(FileImage(file));
        // Delete the plaintext temp file to free disk space.
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final currentFile = _imageFiles[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
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
          // Optimized PageView - EMERGENCY: RepaintBoundary removed due to memory leak
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _imageFiles.length,
            itemBuilder: (context, index) {
              return _OptimizedImagePage(
                file: _imageFiles[index],
                cachedFile: _imageCache[index],
                openService: _openService,
              );
            },
          ),

          // Navigation arrows with better performance
          if (_imageFiles.length > 1) ...[
            // Left arrow
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _currentIndex > 0 ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 200),
                  child: IconButton(
                    onPressed: _currentIndex > 0
                        ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 32),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.5),
                    ),
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
                child: AnimatedOpacity(
                  opacity: _currentIndex < _imageFiles.length - 1 ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 200),
                  child: IconButton(
                    onPressed: _currentIndex < _imageFiles.length - 1
                        ? () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 32),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.5),
                    ),
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

class _OptimizedImagePage extends StatefulWidget {
  const _OptimizedImagePage({
    required this.file,
    required this.openService,
    this.cachedFile,
  });

  final VaultFile file;
  final VaultOpenService openService;
  final File? cachedFile;

  @override
  State<_OptimizedImagePage> createState() => _OptimizedImagePageState();
}

class _OptimizedImagePageState extends State<_OptimizedImagePage> {
  // AutomaticKeepAliveClientMixin intentionally removed.
  // wantKeepAlive=true was pinning every page's decoded bitmap in memory
  // forever, causing OOM after ~200 images. PageView's default ±1 eviction
  // is the correct behaviour — re-entry is fast via decryptToCachedTempFile.
  Future<File>? _future;

  @override
  void initState() {
    super.initState();
    _resolveFuture();
  }

  @override
  void didUpdateWidget(_OptimizedImagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent cached the file after this page was built with null
    // (race between preload and PageView building the widget), switch to
    // the already-available file so we don't keep the full decrypt future.
    if (oldWidget.cachedFile == null && widget.cachedFile != null) {
      setState(() {
        _future = Future.value(widget.cachedFile!);
      });
    }
  }

  void _resolveFuture() {
    if (widget.cachedFile != null) {
      _future = Future.value(widget.cachedFile!);
    } else {
      _future = widget.openService.decryptToCachedTempFile(widget.file);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  'Loading image...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        final file = snapshot.data!;
        final screenSize = MediaQuery.of(context).size;

        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image(
              // Use logical screen pixels — no ×2 multiplier.
              // maxDimension*2 was decoding each image to ~88 MB on 1080p
              // devices; logical pixels cap it to ~10 MB per frame.
              image: ResizeImage(
                FileImage(file),
                width: screenSize.width.round(),
                height: screenSize.height.round(),
                allowUpscaling: false,
              ),
              fit: BoxFit.contain,
              // Performance optimizations
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Could not render this image.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
