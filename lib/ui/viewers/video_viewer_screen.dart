import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/vault_file.dart';
import '../../services/file_crypto_service.dart';
import '../../services/file_open_service.dart';
import '../../services/secure_storage_service.dart';
import '../../services/vault_open_service.dart';
import '../../utils/vault_format.dart';

class VideoViewerScreen extends StatefulWidget {
  const VideoViewerScreen({super.key, required this.file});

  final VaultFile file;

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  late final VaultOpenService _openService = VaultOpenService(
    crypto: const FileCryptoService(),
    secureStorage: SecureStorageService.instance,
    opener: FileOpenService(),
  );

  Future<File>? _tempFuture;
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      setState(() {
        _isInitializing = true;
        _error = null;
      });

      // Show progress for large files
      if (widget.file.byteSize > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Decrypting large video (${formatBytes(widget.file.byteSize)})...'),
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }

      _tempFuture = _openService.decryptToCachedTempFile(widget.file);
      final f = await _tempFuture!;
      
      if (!mounted) return;
      
      // Verify the file exists and is readable
      if (!await f.exists()) {
        throw Exception('Decrypted video file not found');
      }

      final fileSize = await f.length();
      if (fileSize == 0) {
        throw Exception('Decrypted video file is empty');
      }
      
      final c = VideoPlayerController.file(f);
      
      // Add timeout for video initialization
      await c.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Video initialization timed out');
        },
      );
      
      c.setLooping(false); // Don't auto-loop large videos
      
      if (!mounted) {
        await c.dispose();
        return;
      }
      
      setState(() {
        _controller = c;
        _isInitializing = false;
      });

      // Hide progress snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isInitializing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.file.originalName,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              formatBytes(widget.file.byteSize),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open with system app',
            onPressed: () => _openService.decryptToTempAndOpen(widget.file),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load video'),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _initVideo,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isInitializing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Decrypting video...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'File size: ${formatBytes(widget.file.byteSize)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.file.byteSize > 50 * 1024 * 1024)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Large files may take a while to decrypt',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
          ],
        ),
      );
    }

    final c = _controller;
    if (c == null) {
      return const Center(child: Text('Video controller not initialized'));
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
        ),
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              VideoProgressIndicator(
                c,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () async {
                        final pos = c.value.position;
                        await c.seekTo(pos - const Duration(seconds: 10));
                      },
                      icon: const Icon(Icons.replay_10),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          c.value.isPlaying ? c.pause() : c.play();
                        });
                      },
                      icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(c.value.isPlaying ? 'Pause' : 'Play'),
                    ),
                    IconButton(
                      onPressed: () async {
                        final pos = c.value.position;
                        await c.seekTo(pos + const Duration(seconds: 10));
                      },
                      icon: const Icon(Icons.forward_10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

