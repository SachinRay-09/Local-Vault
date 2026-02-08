import '../models/vault_file.dart';
import '../models/vault_folder.dart';
import 'vault_repository.dart';

enum SearchType { all, files, folders }
enum SortBy { name, date, size, relevance, fileOrder }  // Added fileOrder
enum SortOrder { ascending, descending }

class SearchFilter {
  SearchFilter({
    this.query = '',
    this.searchType = SearchType.all,
    this.sortBy = SortBy.relevance,
    this.sortOrder = SortOrder.descending,
    this.mimeTypes = const [],
    this.tags = const [],
    this.minSize,
    this.maxSize,
    this.dateFrom,
    this.dateTo,
    this.folderId,
  });

  final String query;
  final SearchType searchType;
  final SortBy sortBy;
  final SortOrder sortOrder;
  final List<String> mimeTypes;
  final List<String> tags;
  final int? minSize;
  final int? maxSize;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? folderId; // Search within specific folder

  SearchFilter copyWith({
    String? query,
    SearchType? searchType,
    SortBy? sortBy,
    SortOrder? sortOrder,
    List<String>? mimeTypes,
    List<String>? tags,
    int? minSize,
    int? maxSize,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? folderId,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      searchType: searchType ?? this.searchType,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      mimeTypes: mimeTypes ?? this.mimeTypes,
      tags: tags ?? this.tags,
      minSize: minSize ?? this.minSize,
      maxSize: maxSize ?? this.maxSize,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      folderId: folderId ?? this.folderId,
    );
  }
}

class SearchResult {
  SearchResult({
    required this.folders,
    required this.files,
    required this.totalResults,
    required this.searchTime,
  });

  final List<VaultFolder> folders;
  final List<VaultFile> files;
  final int totalResults;
  final Duration searchTime;
}

class AdvancedSearchService {
  AdvancedSearchService({required this.repo});

  final VaultRepository repo;

  Future<SearchResult> search(SearchFilter filter, {int limit = 100}) async {
    final stopwatch = Stopwatch()..start();
    
    List<VaultFolder> folders = [];
    List<VaultFile> files = [];

    // Search folders if requested
    if (filter.searchType == SearchType.all || filter.searchType == SearchType.folders) {
      folders = await _searchFolders(filter, limit: limit ~/ 2);
    }

    // Search files if requested
    if (filter.searchType == SearchType.all || filter.searchType == SearchType.files) {
      final fileLimit = filter.searchType == SearchType.files ? limit : limit - folders.length;
      files = await _searchFiles(filter, limit: fileLimit);
    }

    stopwatch.stop();

    return SearchResult(
      folders: folders,
      files: files,
      totalResults: folders.length + files.length,
      searchTime: stopwatch.elapsed,
    );
  }

  Future<List<VaultFolder>> _searchFolders(SearchFilter filter, {required int limit}) async {
    // Basic folder search - can be enhanced with more complex queries
    final allFolders = await repo.searchFolders(filter.query, limit: limit);
    
    // Apply date filters
    var filteredFolders = allFolders.where((folder) {
      if (filter.dateFrom != null && folder.createdAt.isBefore(filter.dateFrom!)) {
        return false;
      }
      if (filter.dateTo != null && folder.createdAt.isAfter(filter.dateTo!)) {
        return false;
      }
      return true;
    }).toList();

    // Sort folders
    _sortFolders(filteredFolders, filter.sortBy, filter.sortOrder);

    return filteredFolders.take(limit).toList();
  }

  Future<List<VaultFile>> _searchFiles(SearchFilter filter, {required int limit}) async {
    // Basic file search - can be enhanced with more complex queries
    final allFiles = await repo.searchFiles(filter.query, limit: limit * 2); // Get more for filtering
    
    // Apply filters
    var filteredFiles = allFiles.where((file) {
      // MIME type filter
      if (filter.mimeTypes.isNotEmpty && 
          (file.mimeType == null || !filter.mimeTypes.contains(file.mimeType))) {
        return false;
      }
      
      // Size filters
      if (filter.minSize != null && file.byteSize < filter.minSize!) {
        return false;
      }
      if (filter.maxSize != null && file.byteSize > filter.maxSize!) {
        return false;
      }
      
      // Date filters
      if (filter.dateFrom != null && file.createdAt.isBefore(filter.dateFrom!)) {
        return false;
      }
      if (filter.dateTo != null && file.createdAt.isAfter(filter.dateTo!)) {
        return false;
      }
      
      return true;
    }).toList();

    // Sort files
    _sortFiles(filteredFiles, filter.sortBy, filter.sortOrder);

    return filteredFiles.take(limit).toList();
  }

  void _sortFolders(List<VaultFolder> folders, SortBy sortBy, SortOrder order) {
    folders.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case SortBy.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortBy.date:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case SortBy.size:
          comparison = 0; // Folders don't have size
          break;
        case SortBy.fileOrder:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase()); // Folders use name
          break;
        case SortBy.relevance:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
      }
      return order == SortOrder.ascending ? comparison : -comparison;
    });
  }

  void _sortFiles(List<VaultFile> files, SortBy sortBy, SortOrder order) {
    files.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case SortBy.name:
          comparison = a.originalName.toLowerCase().compareTo(b.originalName.toLowerCase());
          break;
        case SortBy.date:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case SortBy.size:
          comparison = a.byteSize.compareTo(b.byteSize);
          break;
        case SortBy.fileOrder:
          comparison = a.sortOrder.compareTo(b.sortOrder);  // Sort by original file system order
          break;
        case SortBy.relevance:
          comparison = a.originalName.toLowerCase().compareTo(b.originalName.toLowerCase());
          break;
      }
      return order == SortOrder.ascending ? comparison : -comparison;
    });
  }

  /// Get available MIME types for filtering
  Future<List<String>> getAvailableMimeTypes() async {
    // This would need to be implemented with a proper database query
    // For now, return common types
    return [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'video/mp4',
      'video/webm',
      'application/pdf',
    ];
  }
}