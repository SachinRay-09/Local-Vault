import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Encryption strategy types
enum EncryptionStrategy {
  individual,     // Individual file encryption (current method)
  container,      // Container-based folder encryption (new method)
  hybrid,         // Mix of both based on content analysis
}

/// Analysis result for encryption strategy
class StrategyAnalysis {
  final EncryptionStrategy recommendedStrategy;
  final String reasoning;
  final Map<String, dynamic> metrics;
  final double performanceGain;
  final double memoryReduction;
  
  StrategyAnalysis({
    required this.recommendedStrategy,
    required this.reasoning,
    required this.metrics,
    required this.performanceGain,
    required this.memoryReduction,
  });
}

/// Smart encryption strategy engine that automatically selects optimal encryption method
class EncryptionStrategyService {
  
  /// Analyzes files and recommends optimal encryption strategy
  static StrategyAnalysis analyzeEncryptionStrategy(List<File> files) {
    debugPrint('Analyzing encryption strategy for ${files.length} files');
    
    if (files.isEmpty) {
      return StrategyAnalysis(
        recommendedStrategy: EncryptionStrategy.individual,
        reasoning: 'No files to analyze',
        metrics: {},
        performanceGain: 0.0,
        memoryReduction: 0.0,
      );
    }
    
    // Collect file metrics
    final metrics = _analyzeFiles(files);
    final fileCount = files.length;
    final totalSize = metrics['totalSize'] as int;
    final imageFiles = metrics['imageFiles'] as int;
    final videoFiles = metrics['videoFiles'] as int;
    final documentFiles = metrics['documentFiles'] as int;
    final otherFiles = metrics['otherFiles'] as int;
    final avgFileSize = totalSize / fileCount;
    
    debugPrint('File analysis: $fileCount files, $imageFiles images, $videoFiles videos, $documentFiles docs, $otherFiles others (avg: ${avgFileSize.toInt()} bytes)');
    
    // Decision logic based on comprehensive analysis
    EncryptionStrategy strategy;
    String reasoning;
    double performanceGain = 0.0;
    double memoryReduction = 0.0;
    
    // Large homogeneous collections (manga, photo albums)
    if (fileCount > 50 && (imageFiles + videoFiles) > fileCount * 0.8) {
      strategy = EncryptionStrategy.container;
      reasoning = 'Large media collection ($fileCount files, ${((imageFiles + videoFiles) / fileCount * 100).toInt()}% media) - container encryption optimal';
      performanceGain = _calculatePerformanceGain(fileCount, true);
      memoryReduction = _calculateMemoryReduction(fileCount, true);
    }
    // Medium collections with similar content
    else if (fileCount > 20 && (imageFiles + videoFiles) > fileCount * 0.7) {
      strategy = EncryptionStrategy.container;
      reasoning = 'Medium media collection ($fileCount files, ${((imageFiles + videoFiles) / fileCount * 100).toInt()}% media) - container encryption beneficial';
      performanceGain = _calculatePerformanceGain(fileCount, false);
      memoryReduction = _calculateMemoryReduction(fileCount, false);
    }
    // Mixed content or sensitive documents
    else if (documentFiles > fileCount * 0.3) {
      strategy = EncryptionStrategy.individual;
      reasoning = 'Mixed content with documents (${(documentFiles / fileCount * 100).toInt()}% docs) - individual encryption for security';
      performanceGain = 0.0;
      memoryReduction = 0.0;
    }
    // Small collections
    else if (fileCount <= 20) {
      strategy = EncryptionStrategy.individual;
      reasoning = 'Small collection ($fileCount files) - individual encryption sufficient';
      performanceGain = 0.0;
      memoryReduction = 0.0;
    }
    // Large mixed collections
    else if (fileCount > 100) {
      strategy = EncryptionStrategy.hybrid;
      reasoning = 'Large mixed collection ($fileCount files) - hybrid approach recommended';
      performanceGain = _calculatePerformanceGain(fileCount, false) * 0.6; // Partial benefit
      memoryReduction = _calculateMemoryReduction(fileCount, false) * 0.6;
    }
    // Default to individual for safety
    else {
      strategy = EncryptionStrategy.individual;
      reasoning = 'Default individual encryption for safety';
      performanceGain = 0.0;
      memoryReduction = 0.0;
    }
    
    debugPrint('Recommended strategy: $strategy - $reasoning');
    
    return StrategyAnalysis(
      recommendedStrategy: strategy,
      reasoning: reasoning,
      metrics: metrics,
      performanceGain: performanceGain,
      memoryReduction: memoryReduction,
    );
  }
  
  /// Analyzes file collection and returns metrics
  static Map<String, dynamic> _analyzeFiles(List<File> files) {
    int totalSize = 0;
    int imageFiles = 0;
    int videoFiles = 0;
    int documentFiles = 0;
    int otherFiles = 0;
    
    final fileSizes = <int>[];
    final extensions = <String, int>{};
    
    for (final file in files) {
      try {
        final size = file.lengthSync();
        totalSize += size;
        fileSizes.add(size);
        
        final ext = path.extension(file.path).toLowerCase();
        extensions[ext] = (extensions[ext] ?? 0) + 1;
        
        // Categorize file types
        if (_isImageFile(ext)) {
          imageFiles++;
        } else if (_isVideoFile(ext)) {
          videoFiles++;
        } else if (_isDocumentFile(ext)) {
          documentFiles++;
        } else {
          otherFiles++;
        }
      } catch (e) {
        debugPrint('Error analyzing file ${file.path}: $e');
        otherFiles++;
      }
    }
    
    // Calculate statistics
    fileSizes.sort();
    final medianSize = fileSizes.isNotEmpty 
        ? fileSizes[fileSizes.length ~/ 2] 
        : 0;
    
    return {
      'totalSize': totalSize,
      'imageFiles': imageFiles,
      'videoFiles': videoFiles,
      'documentFiles': documentFiles,
      'otherFiles': otherFiles,
      'avgSize': totalSize / files.length,
      'medianSize': medianSize,
      'extensions': extensions,
      'fileSizes': fileSizes,
    };
  }
  
  /// Calculates expected performance gain from container encryption
  static double _calculatePerformanceGain(int fileCount, bool isLargeCollection) {
    if (fileCount <= 20) return 0.0;
    
    // Base performance gain calculation
    double baseGain = 0.0;
    
    if (fileCount > 100) {
      baseGain = 0.85; // 85% improvement for very large collections
    } else if (fileCount > 50) {
      baseGain = 0.70; // 70% improvement for large collections
    } else {
      baseGain = 0.50; // 50% improvement for medium collections
    }
    
    // Adjust for collection type
    if (isLargeCollection) {
      baseGain *= 1.1; // 10% bonus for homogeneous collections
    }
    
    return baseGain.clamp(0.0, 0.90); // Cap at 90% improvement
  }
  
  /// Calculates expected memory reduction from container encryption
  static double _calculateMemoryReduction(int fileCount, bool isLargeCollection) {
    if (fileCount <= 20) return 0.0;
    
    // Memory reduction is significant due to reduced metadata overhead
    double baseReduction = 0.0;
    
    if (fileCount > 100) {
      baseReduction = 0.80; // 80% memory reduction for very large collections
    } else if (fileCount > 50) {
      baseReduction = 0.65; // 65% memory reduction for large collections
    } else {
      baseReduction = 0.40; // 40% memory reduction for medium collections
    }
    
    // Adjust for collection type
    if (isLargeCollection) {
      baseReduction *= 1.1; // 10% bonus for homogeneous collections
    }
    
    return baseReduction.clamp(0.0, 0.85); // Cap at 85% reduction
  }
  
  /// Checks if file extension is an image
  static bool _isImageFile(String extension) {
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.svg'].contains(extension);
  }
  
  /// Checks if file extension is a video
  static bool _isVideoFile(String extension) {
    return ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v'].contains(extension);
  }
  
  /// Checks if file extension is a document
  static bool _isDocumentFile(String extension) {
    return ['.pdf', '.doc', '.docx', '.txt', '.rtf', '.odt', '.xls', '.xlsx', '.ppt', '.pptx'].contains(extension);
  }
  
  /// Gets user-friendly description of strategy benefits
  static String getStrategyDescription(EncryptionStrategy strategy, int fileCount) {
    switch (strategy) {
      case EncryptionStrategy.individual:
        return 'Each file encrypted separately for maximum security and granular access.';
      
      case EncryptionStrategy.container:
        return 'Files grouped in encrypted container for ${fileCount > 50 ? '70-85%' : '50-70%'} faster processing and reduced memory usage.';
      
      case EncryptionStrategy.hybrid:
        return 'Smart mix of individual and container encryption based on file types and sensitivity.';
    }
  }
  
  /// Gets performance impact description
  static String getPerformanceImpact(double performanceGain, double memoryReduction) {
    if (performanceGain == 0.0 && memoryReduction == 0.0) {
      return 'Standard performance with maximum security.';
    }
    
    final perfPercent = (performanceGain * 100).toInt();
    final memPercent = (memoryReduction * 100).toInt();
    
    return 'Expected: $perfPercent% faster processing, $memPercent% less memory usage.';
  }
}