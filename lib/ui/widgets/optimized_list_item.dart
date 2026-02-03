import 'package:flutter/material.dart';

import '../../models/vault_file.dart';
import '../../models/vault_folder.dart';
import '../../utils/vault_format.dart';
import 'context_menu_region.dart';

class OptimizedFolderItem extends StatelessWidget {
  const OptimizedFolderItem({
    super.key,
    required this.folder,
    required this.isSelected,
    required this.multiSelectMode,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.contextMenuBuilder,
  });

  final VaultFolder folder;
  final bool isSelected;
  final bool multiSelectMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onToggleSelection;
  final Widget Function(VaultFolder folder, VoidCallback onClose) contextMenuBuilder;

  @override
  Widget build(BuildContext context) {
    return ContextMenuRegion(
      contextMenuBuilder: (context, offset, onClose) => contextMenuBuilder(folder, onClose),
      child: ListTile(
        leading: multiSelectMode 
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => onToggleSelection(),
              )
            : const Icon(Icons.folder),
        title: Text(folder.name),
        onTap: multiSelectMode ? onToggleSelection : onTap,
        onLongPress: multiSelectMode ? null : onLongPress,
      ),
    );
  }
}

class OptimizedFileItem extends StatelessWidget {
  const OptimizedFileItem({
    super.key,
    required this.file,
    required this.isSelected,
    required this.multiSelectMode,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.isImage,
  });

  final VaultFile file;
  final bool isSelected;
  final bool multiSelectMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onToggleSelection;
  final bool isImage;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: multiSelectMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onToggleSelection(),
            )
          : isImage
              ? Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.image,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                )
              : const Icon(Icons.insert_drive_file),
      title: Text(file.originalName),
      subtitle: Text('${formatBytes(file.byteSize)} • ${formatLocalDateTime(file.createdAt)}'),
      onTap: multiSelectMode ? onToggleSelection : onTap,
      onLongPress: multiSelectMode ? null : onLongPress,
    );
  }
}

class OptimizedGridFileItem extends StatelessWidget {
  const OptimizedGridFileItem({
    super.key,
    required this.file,
    required this.isSelected,
    required this.multiSelectMode,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.isImage,
  });

  final VaultFile file;
  final bool isSelected;
  final bool multiSelectMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onToggleSelection;
  final bool isImage;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: multiSelectMode ? onToggleSelection : onTap,
      onLongPress: multiSelectMode ? null : onLongPress,
      child: Stack(
        children: [
          Ink(
            decoration: BoxDecoration(
              color: multiSelectMode && isSelected
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: multiSelectMode && isSelected
                  ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: isImage
                          ? Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.image,
                                size: 40,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            )
                          : const Icon(Icons.insert_drive_file_outlined, size: 40),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    file.originalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    formatBytes(file.byteSize),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (multiSelectMode)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Icon(
                  isSelected ? Icons.check : null,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : null,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}