# Development Progress: Local Vault

Last updated: 2026-02-02

## Goals (non-negotiable)
- 100% offline, no cloud
- **DB stores only plaintext metadata** (folder tree, filenames, blob pointers)
- **Files on disk are encrypted blobs** with random names
- Export/import uses `archive` password-protected `ZipFileEncoder` (don't manually encrypt zip bytes unless necessary)

## Status summary
- **Current milestone**: Feature complete with all analysis issues resolved
- **Overall progress (rough)**: **100%**

## Can I use it already?
- **Make folders**: Yes
- **Store/import media/files into the vault**: Yes (Add Media)
- **Performance optimized**: Yes (smooth navigation, no loading symbols)
- **Batch operations**: Yes (multi-select for bulk actions)
- **Complete feature set**: Yes (all planned features implemented)

## Did we achieve the original plan?
- **Yes (core plan)**: Offline vault, unlimited folders, encrypted file blobs, import/export password zip, open media, basic settings.
- **Performance enhanced**: Thumbnail system, pagination, smooth image navigation, optimized video playback
- **Notes**: DB is plaintext metadata (fast). Files are encrypted on disk.

## Completed
- **Packages added**: `isar`, `isar_flutter_libs`, `path_provider`, `flutter_secure_storage`, `encrypt`, `file_picker`, `archive`
- **Spec updated**: clarified security model + export/import rules
- **Project scaffold created**:
  - `lib/app/app.dart`
  - `lib/db/isar_db.dart`
  - `lib/models/*` (Isar collections)
  - `lib/services/*` (paths/crypto/export scaffolds)
  - `lib/ui/home/home_screen.dart` (UI skeleton)
- **Database initialization**: `main.dart` opens Isar at startup
- **Isar codegen**: `.g.dart` generated
- **Auth v1 (password gate)**:
  - First-run setup screen (password + 2 recovery questions)
  - Unlock screen
  - "Forgot password" recovery flow using the 2 questions
  - Password reset keeps the same master key (files remain decryptable)
- **Auth hardening v1**:
  - Password hashing upgraded to PBKDF2 (legacy hash auto-migrates on successful login)
  - Basic lockout/rate-limiting after repeated failed attempts
- **Open media v1**:
  - Tap a stored file -> decrypt blob to `vault_tmp/` (cache) with original extension
  - Open using OS default app (Windows via shell, Android via FileProvider + intent)
- **Import/Export v1**:
  - Export: creates a password-protected ZIP (uses `ZipFileEncoder(password: ...)`) and shows the password
  - Import: picks a ZIP + asks password + extracts + recreates folders and re-encrypts files into blobs
- **Settings v1**:
  - View vault stats (folders/files/used space)
  - Set optional max storage limit (blocks Add Media when limit is reached)
  - Clear temp cache
  - Lock vault
- **Manage items v1**:
  - Breadcrumb navigation (Root / nested folders)
  - Long-press a folder/file to Rename or Delete
  - Deleting a file removes its encrypted blob from disk (best-effort)
- **UI polish v1**:
  - Cleaner top bar (icon actions + overflow menu)
  - Simple modern Material 3 theme
  - Settings screen layout cleaned up
- **Search + sort v1**:
  - Search/filter in the current folder view
  - Sort files by name/date/size
  - Toggle ascending/descending
- **Global search + quick lock v1**:
  - Search across the whole vault (folders + files)
  - Jump to the folder location of a result
  - Lock vault from the Home menu
- **Move v1**:
  - Move files and folders into another folder (or Root)
  - Prevent moving a folder into itself or its subfolders
- **Performance optimizations v1** (NEW):
  - **Thumbnail system**: Fast, cached thumbnails instead of decrypting full images
  - **Pagination**: Load files in chunks (50 per page) for large folders
  - **Image gallery navigation**: Swipe between images with left/right arrows
  - **Optimized video player**: Better progress indication for large video files
  - **Memory management**: Thumbnail caching with automatic cleanup
- **Batch operations v1** (NEW):
  - **Multi-select mode**: Select multiple files and folders
  - **Bulk delete**: Delete multiple items at once
  - **Selection indicators**: Visual feedback for selected items
  - **Batch UI**: Clean interface for managing selections
- **Advanced features v1** (NEW):
  - **Bulk folder import**: Import entire folders with all images
  - **Optimized image viewer**: Smooth navigation with preloading
  - **Yomikiru integration**: Open manga folders in external reader
  - **Performance optimizations**: RepaintBoundary, memory management
- **Code quality v1** (NEW):
  - **Flutter analysis**: All analysis issues resolved
  - **BuildContext safety**: Fixed async context usage patterns
  - **Windows testing**: App builds and runs successfully on Windows
  - **Context menu fix**: Fixed right-click context menus for folders
  - **Yomikiru integration**: Debugged and verified working integration
  - **Performance optimizations**: Added RepaintBoundary widgets and optimized list rendering

## What's left (realistic)
- **All core features completed!** 🎉
- **Optional future enhancements**:
  - Better metadata: mime detection improvements, modified timestamps
  - Performance polish: background tasks for very large imports/exports
  - UX polish: undo for delete, more confirm dialogs
  - Advanced features: file tagging, advanced search filters

## Next up (planned)
- **App is feature complete!** Ready for daily use with manga collections and large media files.

## Performance Improvements Completed
- **Thumbnail Generation**: 
  - Small cached thumbnails (200px) instead of full image decryption
  - Memory and disk caching for instant loading
  - Skip thumbnails for files > 50MB to avoid memory issues
- **Pagination**:
  - Load 50 files at a time with "Load more" button
  - Prevents UI lag in folders with hundreds of manga images
  - Shows remaining file count
- **Image Navigation**:
  - Swipe between images in the same folder
  - Left/right arrow buttons for desktop
  - Page counter (e.g., "5 of 120")
  - Black background for better manga reading experience
- **Video Optimization**:
  - Progress indication for large video decryption
  - Better error handling and retry functionality
  - File size display in video player
  - Warning for very large files (>50MB)
- **Batch Operations** (NEW):
  - Multi-select mode with checkbox interface
  - Bulk delete for files and folders
  - Visual selection indicators in both list and grid views
  - Clean batch operation UI with selection counter
- **Advanced Import/Export** (NEW):
  - Bulk folder import with progress tracking
  - Handles large manga collections (500+ images per folder)
  - Maintains folder structure during import
  - Error handling and progress reporting
- **Yomikiru Integration** (NEW):
  - Export folders to temporary location for external manga reader
  - Automatic Yomikiru launch (if installed)
  - Maintains reading order and folder structure
  - Cleanup of temporary files

## Optimization / "don't waste GBs"
- **No duplicate storage**: never keep decrypted copies permanently (only temporary cache).
- **No DB encryption**: keep Isar plaintext metadata for speed.
- **Streaming encryption** (preferred for large videos): encrypt file -> blob without loading whole file into RAM.
- **Export strategy**: only decrypt on-the-fly into the zip; no staging decrypted copies unless required.
- **Thumbnail caching**: Small thumbnails cached to avoid repeated full-file decryption.
- **Release builds**:
  - Android: `--release --split-per-abi --tree-shake-icons`
  - Windows: `--release`

## Known build notes
- Windows plugin builds require symlink support (Developer Mode enabled).

## Performance Testing Results
- **Large folders**: Smooth navigation with 500+ manga images
- **Video playback**: 168MB+ videos load with progress indication  
- **Memory usage**: Optimized with simple icons instead of heavy thumbnails
- **UI responsiveness**: No more laggy folder navigation or media opening
- **Batch operations**: Select and delete multiple items efficiently
- **Multi-select**: Smooth selection interface for managing large collections