import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/vault_file.dart';
import '../../services/file_crypto_service.dart';
import '../../services/file_open_service.dart';
import '../../services/secure_storage_service.dart';
import '../../services/vault_open_service.dart';
import '../../services/vault_repository.dart';
import '../../utils/vault_format.dart';

// ---------------------------------------------------------------------------
// ImageViewerScreen — crossfade viewer, no black flash
// ---------------------------------------------------------------------------
//
// Why previous attempts still flashed:
//
//   animateToPage() fires onPageChanged() at the moment the page SNAPS
//   (start of the slide animation), not when it finishes.  During the 220ms
//   slide, PageView's viewport reveals the incoming page.  Even if _resolved
//   has the File, Image.file still needs one raster frame to push pixels to
//   the GPU.  During that one frame the black Scaffold background is visible
//   through the slide transition.  precacheImage helps but cannot guarantee
//   the raster upload completes before the frame is composited.
//
// Solution — eliminate the slide animation entirely:
//
//   We do NOT use PageView for transitions.  We use a single AnimatedSwitcher
//   with a FadeTransition so the incoming image fades in OVER the outgoing
//   image.  There is no viewport gap, no background reveal, no slide.
//   The fade starts only after _resolved[nextIndex] is ready AND precacheImage
//   has completed — both are awaited before the fade begins.
//
//   The navigation button tap:
//     1. Start decrypt + precacheImage for target (await both).
//     2. Only then setState to update _currentIndex → AnimatedSwitcher fades.
//     3. No black frame possible: the old image is still fully visible until
//        the new one is pixel-perfect ready.
//
//   For OOM safety:
//     _resolved keeps at most ±_kKeepRadius pages as File references.
//     Images beyond _kEvictBeyond have their Flutter cache entry evicted
//     and their temp file deleted.

const int _kPreloadRadius = 2; // preload this many pages ahead and behind
const int _kEvictBeyond = 4; // evict decoded bitmaps beyond this distance

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

  List<VaultFile> _imageFiles = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _navigating = false; // true while an async navigation is in progress

  // index → already-decrypted and pre-rasterised File
  final Map<int, File> _resolved = {};
  // indices currently being decrypted
  final Set<int> _inFlight = {};

  @override
  void initState() {
    super.initState();
    _initializeImages();
  }

  @override
  void dispose() {
    _evictAll();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Initialisation
  // -------------------------------------------------------------------------

  Future<void> _initializeImages() async {
    List<VaultFile> allFiles = widget.allFiles ?? [];
    if (allFiles.isEmpty) {
      allFiles = await _repo.listFiles(parentId: widget.file.parentFolderId);
    }

    _imageFiles =
        allFiles.where((f) => isImageFileName(f.originalName)).toList();

    _currentIndex = _imageFiles.indexWhere((f) => f.id == widget.file.id);
    if (_currentIndex < 0) {
      _currentIndex = 0;
      if (_imageFiles.isEmpty) _imageFiles = [widget.file];
    }

    // Decrypt and pre-rasterise the current image BEFORE showing it.
    await _decryptAndCache(_currentIndex);

    if (mounted) setState(() => _loading = false);

    // Background-preload neighbours.
    _scheduleWindow(_currentIndex);
  }

  // -------------------------------------------------------------------------
  // Decrypt one index: file I/O + precacheImage (both awaited)
  // -------------------------------------------------------------------------

  Future<void> _decryptAndCache(int index) async {
    if (_resolved.containsKey(index)) return;
    if (_inFlight.contains(index)) {
      // Wait for the already-running decrypt to finish.
      while (_inFlight.contains(index)) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      return;
    }
    if (index < 0 || index >= _imageFiles.length) return;

    _inFlight.add(index);
    try {
      final file =
          await _openService.decryptToCachedTempFile(_imageFiles[index]);
      if (!mounted) return;

      // precacheImage pushes the decoded bitmap into Flutter's raster cache.
      // Awaiting it means Image.file will render in zero frames — no decode
      // stall, no black flash.
      await precacheImage(FileImage(file), context);

      if (!mounted) return;
      _resolved[index] = file;
      // Rebuild so navigation buttons can re-evaluate _canGoPrev/_canGoNext.
      setState(() {});
    } catch (e) {
      debugPrint('[ImageViewer] decrypt failed at $index: $e');
    } finally {
      _inFlight.remove(index);
    }
  }

  // -------------------------------------------------------------------------
  // Background preload window
  // -------------------------------------------------------------------------

  void _scheduleWindow(int center) {
    for (var i = center - _kPreloadRadius; i <= center + _kPreloadRadius; i++) {
      if (i != center && i >= 0 && i < _imageFiles.length) {
        _decryptAndCache(i); // fire-and-forget
      }
    }
    // Evict pages far outside the window.
    for (final i in _resolved.keys
        .where((i) => (i - center).abs() > _kEvictBeyond)
        .toList()) {
      _evictIndex(i);
    }
  }

  void _evictIndex(int index) {
    final file = _resolved.remove(index);
    if (file == null) return;
    PaintingBinding.instance.imageCache.evict(FileImage(file));
    try {
      file.deleteSync();
    } catch (_) {}
  }

  void _evictAll() {
    for (final i in _resolved.keys.toList()) {
      _evictIndex(i);
    }
  }

  // -------------------------------------------------------------------------
  // Navigation — await decrypt+rasterise, then crossfade
  // -------------------------------------------------------------------------

  bool get _canGoPrev => _currentIndex > 0 && !_navigating;
  bool get _canGoNext => _currentIndex < _imageFiles.length - 1 && !_navigating;

  Future<void> _navigateTo(int targetIndex) async {
    if (_navigating) return;
    if (targetIndex < 0 || targetIndex >= _imageFiles.length) return;

    setState(() => _navigating = true);

    try {
      // Ensure the target is fully ready (decrypt + precacheImage) before
      // changing _currentIndex.  The old image remains fully visible during
      // this wait — no black frame possible.
      await _decryptAndCache(targetIndex);

      if (!mounted) return;

      setState(() {
        _currentIndex = targetIndex;
        _navigating = false;
      });

      // Preload new neighbours in background.
      _scheduleWindow(targetIndex);
    } catch (e) {
      if (mounted) setState(() => _navigating = false);
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final currentFile = _imageFiles[_currentIndex];
    final resolvedFile = _resolved[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentFile.originalName,
                style: const TextStyle(fontSize: 16)),
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
            onPressed: resolvedFile == null
                ? null
                : () => _openService.decryptToTempAndOpen(currentFile),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Image area: AnimatedSwitcher crossfade ──────────────────────
          //
          // AnimatedSwitcher swaps children with a FadeTransition when the
          // key changes (_currentIndex).  The outgoing image stays fully
          // opaque until the incoming one is composited on top — the black
          // Scaffold is NEVER exposed during the transition.
          Positioned.fill(
            child: resolvedFile == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 12),
                        Text('Decrypting…',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: _ImagePage(
                      // Key change triggers the crossfade.
                      key: ValueKey(_imageFiles[_currentIndex].id),
                      file: resolvedFile,
                    ),
                  ),
          ),

          // ── Navigation buttons ──────────────────────────────────────────
          if (_imageFiles.length > 1) ...[
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavButton(
                  icon: Icons.arrow_back_ios,
                  enabled: _canGoPrev,
                  // Show spinner while target is being prepared.
                  loading: _navigating && _currentIndex > 0,
                  onTap: () => _navigateTo(_currentIndex - 1),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavButton(
                  icon: Icons.arrow_forward_ios,
                  enabled: _canGoNext,
                  loading:
                      _navigating && _currentIndex < _imageFiles.length - 1,
                  onTap: () => _navigateTo(_currentIndex + 1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pure display widget — already-decoded File, no async work
// ---------------------------------------------------------------------------

class _ImagePage extends StatelessWidget {
  const _ImagePage({super.key, required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4,
      child: Center(
        child: Image.file(
          file,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Could not render this image.',
                style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation button with loading state indicator
// ---------------------------------------------------------------------------

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(26),
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(
                  color: Colors.white54, strokeWidth: 2),
            )
          : IconButton(
              padding: EdgeInsets.zero,
              onPressed: enabled ? onTap : null,
              icon: Icon(icon,
                  color: enabled ? Colors.white : Colors.white24, size: 28),
            ),
    );
  }
}
