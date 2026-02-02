import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class FileMetadata {
  FileMetadata({
    required this.mimeType,
    required this.fileSize,
    required this.lastModified,
    this.imageWidth,
    this.imageHeight,
    this.duration,
  });

  final String mimeType;
  final int fileSize;
  final DateTime lastModified;
  final int? imageWidth;
  final int? imageHeight;
  final Duration? duration;
}

class MetadataService {
  /// Extract comprehensive metadata from a file
  static Future<FileMetadata> extractMetadata(File file) async {
    final stat = await file.stat();
    final extension = path.extension(file.path).toLowerCase();
    
    return FileMetadata(
      mimeType: _getMimeType(extension),
      fileSize: stat.size,
      lastModified: stat.modified,
      imageWidth: await _getImageWidth(file, extension),
      imageHeight: await _getImageHeight(file, extension),
      duration: await _getVideoDuration(file, extension),
    );
  }

  /// Get MIME type from file extension
  static String _getMimeType(String extension) {
    switch (extension) {
      // Images
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      case '.svg':
        return 'image/svg+xml';
      case '.avif':
        return 'image/avif';
      case '.apng':
        return 'image/apng';
      
      // Videos
      case '.mp4':
        return 'video/mp4';
      case '.avi':
        return 'video/x-msvideo';
      case '.mov':
        return 'video/quicktime';
      case '.wmv':
        return 'video/x-ms-wmv';
      case '.flv':
        return 'video/x-flv';
      case '.webm':
        return 'video/webm';
      case '.mkv':
        return 'video/x-matroska';
      
      // Documents
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      
      // Archives
      case '.zip':
        return 'application/zip';
      case '.rar':
        return 'application/vnd.rar';
      case '.7z':
        return 'application/x-7z-compressed';
      
      default:
        return 'application/octet-stream';
    }
  }

  /// Extract image dimensions (basic implementation)
  static Future<int?> _getImageWidth(File file, String extension) async {
    if (!_isImageFile(extension)) return null;
    
    try {
      // For now, return null - would need image processing library for full implementation
      // Could use packages like 'image' for detailed metadata extraction
      return null;
    } catch (e) {
      debugPrint('Failed to get image width: $e');
      return null;
    }
  }

  /// Extract image height (basic implementation)
  static Future<int?> _getImageHeight(File file, String extension) async {
    if (!_isImageFile(extension)) return null;
    
    try {
      // For now, return null - would need image processing library for full implementation
      return null;
    } catch (e) {
      debugPrint('Failed to get image height: $e');
      return null;
    }
  }

  /// Extract video duration (basic implementation)
  static Future<Duration?> _getVideoDuration(File file, String extension) async {
    if (!_isVideoFile(extension)) return null;
    
    try {
      // For now, return null - would need video processing library for full implementation
      // Could use packages like 'video_player' or FFmpeg bindings
      return null;
    } catch (e) {
      debugPrint('Failed to get video duration: $e');
      return null;
    }
  }

  static bool _isImageFile(String extension) {
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.apng', '.avif']
        .contains(extension);
  }

  static bool _isVideoFile(String extension) {
    return ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.mkv']
        .contains(extension);
  }

  /// Format file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format duration in human readable format
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}