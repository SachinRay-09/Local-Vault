import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/vault_file.dart';
import '../models/vault_folder.dart';

abstract class UndoAction {
  String get description;
  Future<void> undo();
  Future<void> redo();
}

class DeleteFileAction extends UndoAction {
  DeleteFileAction({
    required this.file,
    required this.onUndo,
    required this.onRedo,
  });

  final VaultFile file;
  final Future<void> Function(VaultFile) onUndo;
  final Future<void> Function(VaultFile) onRedo;

  @override
  String get description => 'Delete "${file.originalName}"';

  @override
  Future<void> undo() async {
    await onUndo(file);
  }

  @override
  Future<void> redo() async {
    await onRedo(file);
  }
}

class DeleteFolderAction extends UndoAction {
  DeleteFolderAction({
    required this.folder,
    required this.onUndo,
    required this.onRedo,
  });

  final VaultFolder folder;
  final Future<void> Function(VaultFolder) onUndo;
  final Future<void> Function(VaultFolder) onRedo;

  @override
  String get description => 'Delete folder "${folder.name}"';

  @override
  Future<void> undo() async {
    await onUndo(folder);
  }

  @override
  Future<void> redo() async {
    await onRedo(folder);
  }
}

class MoveFileAction extends UndoAction {
  MoveFileAction({
    required this.file,
    required this.oldParentId,
    required this.newParentId,
    required this.onMove,
  });

  final VaultFile file;
  final int? oldParentId;
  final int? newParentId;
  final Future<void> Function(VaultFile, int?) onMove;

  @override
  String get description => 'Move "${file.originalName}"';

  @override
  Future<void> undo() async {
    await onMove(file, oldParentId);
  }

  @override
  Future<void> redo() async {
    await onMove(file, newParentId);
  }
}

class UndoService extends ChangeNotifier {
  static const int _maxHistorySize = 50;
  
  final Queue<UndoAction> _undoStack = Queue<UndoAction>();
  final Queue<UndoAction> _redoStack = Queue<UndoAction>();

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  String? get nextUndoDescription => _undoStack.isEmpty ? null : _undoStack.last.description;
  String? get nextRedoDescription => _redoStack.isEmpty ? null : _redoStack.last.description;

  void addAction(UndoAction action) {
    _undoStack.addLast(action);
    _redoStack.clear(); // Clear redo stack when new action is added
    
    // Limit history size
    while (_undoStack.length > _maxHistorySize) {
      _undoStack.removeFirst();
    }
    
    notifyListeners();
  }

  Future<void> undo() async {
    if (!canUndo) return;
    
    final action = _undoStack.removeLast();
    try {
      await action.undo();
      _redoStack.addLast(action);
      notifyListeners();
    } catch (e) {
      // If undo fails, put the action back
      _undoStack.addLast(action);
      debugPrint('Undo failed: $e');
      rethrow;
    }
  }

  Future<void> redo() async {
    if (!canRedo) return;
    
    final action = _redoStack.removeLast();
    try {
      await action.redo();
      _undoStack.addLast(action);
      notifyListeners();
    } catch (e) {
      // If redo fails, put the action back
      _redoStack.addLast(action);
      debugPrint('Redo failed: $e');
      rethrow;
    }
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}