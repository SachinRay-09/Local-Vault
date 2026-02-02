# Project Spec: Local Secure Vault App (Offline)

## Core philosophy
- 100% local. No cloud. No network required for core app behavior.
- One codebase: Windows + Android.
- **Database is NOT encrypted** (for speed). It stores only metadata (virtual folder structure + file metadata).
- **Files ARE encrypted** at rest as random-named blobs inside the app sandbox.

## Storage layout (on-device)
- **Isar DB directory**: app-private support directory.
- **Vault blobs directory**: app-private directory (e.g. `.../vault_blobs/`).
- **Temp/decrypted previews**: app cache/temp directory (short-lived; best-effort cleanup).

Example mental model (correct approach):
- DB says: `"Holiday.jpg" is in Folder A` (plain text metadata, but still inside the app’s private sandbox).
- Disk stores: `3948-2394.bin` (encrypted bytes).

## Security model
- **App password**:
  - First launch: user sets password.
  - Subsequent launches: user must unlock with password.
  - Store only a **salted password hash** in `flutter_secure_storage` (never plaintext).
- **Master key**:
  - Generate a random 32-byte key once, store it in `flutter_secure_storage`.
  - When app is unlocked, load the master key and use it for file encryption/decryption.
- **Password recovery**:
  - Two security questions stored as **salted hashes** (answers never stored plaintext).
  - If answered correctly, allow password reset (master key stays the same so files remain decryptable).

## Data model (Isar, plaintext metadata)
### `VaultFolder`
- `id`: auto-increment
- `name`: folder display name
- `parentId`: nullable (null = root)
- `createdAt`, `updatedAt`

### `VaultFile`
- `id`: auto-increment
- `parentFolderId`: nullable (null = root)
- `originalName`: e.g. `Holiday.jpg`
- `mimeType`, `byteSize`
- `storedBlobName`: random name on disk, e.g. `3948-2394.bin`
- `encryption`:
  - `ivBase64`: IV used for encryption (stored in DB)
  - (optional later) `macBase64` / auth tag depending on chosen mode
- `createdAt`

### `AppSettings` (optional)
- `maxStorageBytes`
- UI preferences, etc.

## Core flows
### Add new folder
- Create a `VaultFolder` with `parentId = currentFolderId` (or null for root).

### Add media
1. Pick file (`file_picker`).
2. Read bytes (or stream later).
3. Generate random `storedBlobName` (not the original name).
4. **Encrypt bytes (AES-256)** and write to `vault_blobs/<storedBlobName>`.
5. Write metadata row to Isar (`VaultFile`).

### Open media
1. Lookup `VaultFile` in Isar.
2. Read encrypted blob from disk.
3. Decrypt to cache/temp file.
4. Open with a viewer (implementation later).

## Import / Export (password-protected zip)
Key rule: **Use the `archive` package Zip encoder with password protection. Do not manually encrypt zip bytes unless necessary.**

### Export
1. User selects folders/files to export (or “Export All”).
2. App generates a random export password and shows it once to the user.
3. App builds a ZIP representing the **visible file structure** (folders + files with their original filenames).
4. While writing the ZIP:
   - For each file, decrypt its blob in-memory/stream and add the decrypted bytes to the ZIP entry path.
   - The ZIP is password-protected using the archive encoder’s built-in password support.
5. Save zip to user-chosen location (Downloads/Desktop/etc).

### Import
1. User picks the exported ZIP.
2. App asks for password.
3. Unzip into temp.
4. Traverse folder structure; for each file:
   - Encrypt file bytes into a new random blob name under `vault_blobs/`
   - Insert folder + file metadata into Isar.

## UI (high-level)
- Launch -> password gate (setup if first run, otherwise unlock).
- After unlock: main screen shows a simple file explorer.
- App bar actions: **Add New Folder**, **Add Media**, **Import**, **Export**, **Settings**.