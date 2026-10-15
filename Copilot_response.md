The app’s primary problem is not its choice of Flutter or Isar. Its primary problems are:

The password does not cryptographically control the vault key.
CPU-heavy cryptography and KDF work can block the UI.
Import and export are implemented through several competing pipelines.
ZIP and container paths can load entire archives into memory.
The two home screens contain application logic.
Jobs are not transactional, recoverable, or consistently cancellable.
Existing “performance services” do not affect the real hot path.
AES-CTR is used without a clearly documented authentication mechanism.

These conclusions follow directly from the current implementation described in your two documents.

1. What should remain
Keep Flutter

Flutter is not the fundamental bottleneck. The documents show that expensive PBKDF2, encryption, archive processing and orchestration occur through the UI-facing execution path.

Flutter’s official guidance confirms that expensive computations should be moved away from the main isolate when they cause frame delays. Isolates do not share memory and communicate through messages, which makes them suitable for coordinating background work, but not necessarily for copying enormous byte arrays repeatedly.

Keep Isar, for now

There is no evidence in the supplied analysis that Isar itself is the major performance problem. The inefficient pattern is the application repeatedly loading all file rows to calculate used storage, as well as performing fragmented per-file persistence.

Fix those access patterns before considering a database replacement.

Keep individual encrypted blobs

Individual blobs support:

Random access.
Per-file deletion.
Incremental imports.
Small recovery units.
On-demand viewing.
Lower peak memory.
Easier corruption isolation.

The existing in-memory TAR/container design works against these requirements and can require decrypting an entire container to retrieve one item. It should not remain a normal storage strategy.

Keep platform-specific shells

Windows and Android genuinely require different picking, sharing, external-reader and storage-access integrations. The problem is not having two shells. The problem is duplicating application logic inside those shells.

Use:

DesktopShell
MobileShell

But give both shells the same controllers and use cases.

2. Recommended architecture

I recommend the following practical structure:

Plain Text
lib/
├── main.dart
│
├── app/
│ ├── local_vault_app.dart
│ ├── bootstrap.dart
│ ├── dependency_container.dart
│ ├── app_router.dart
│ └── app_lifecycle_coordinator.dart
│
├── core/
│ ├── errors/
│ │ ├── app_failure.dart
│ │ ├── crypto_failure.dart
│ │ ├── storage_failure.dart
│ │ └── import_failure.dart
│ ├── result/
│ │ └── result.dart
│ ├── cancellation/
│ │ └── cancellation_token.dart
│ ├── logging/
│ │ ├── app_logger.dart
│ │ └── sensitive_log_filter.dart
│ ├── progress/
│ │ └── operation_progress.dart
│ ├── platform/
│ │ ├── platform_info.dart
│ │ └── device_work_policy.dart
│ └── security/
│ ├── secret_bytes.dart
│ └── constant_time.dart
│
├── domain/
│ ├── entities/
│ │ ├── vault_item.dart
│ │ ├── vault_file.dart
│ │ ├── vault_folder.dart
│ │ ├── vault_session.dart
│ │ ├── import_source.dart
│ │ ├── operation_job.dart
│ │ └── storage_usage.dart
│ ├── repositories/
│ │ ├── vault_repository.dart
│ │ ├── job_repository.dart
│ │ ├── settings_repository.dart
│ │ └── credential_repository.dart
│ └── services/
│ ├── vault_crypto.dart
│ ├── blob_store.dart
│ ├── archive_reader.dart
│ ├── archive_writer.dart
│ └── external_reader.dart
│
├── application/
│ ├── auth/
│ │ ├── initialise_vault.dart
│ │ ├── unlock_vault.dart
│ │ ├── lock_vault.dart
│ │ └── change_password.dart
│ ├── browser/
│ │ ├── list_folder.dart
│ │ ├── search_vault.dart
│ │ ├── create_folder.dart
│ │ └── move_items.dart
│ ├── jobs/
│ │ ├── job_scheduler.dart
│ │ ├── job_runner.dart
│ │ ├── job_recovery.dart
│ │ └── job_policy.dart
│ ├── import/
│ │ ├── create_import_plan.dart
│ │ ├── execute_import.dart
│ │ └── import_coordinator.dart
│ ├── export/
│ │ ├── create_export_plan.dart
│ │ ├── execute_export.dart
│ │ └── export_coordinator.dart
│ └── reader/
│ └── open_in_external_reader.dart
│
├── infrastructure/
│ ├── persistence/
│ │ └── isar/
│ │ ├── collections/
│ │ ├── mappers/
│ │ ├── isar_vault_repository.dart
│ │ ├── isar_job_repository.dart
│ │ └── isar_settings_repository.dart
│ ├── crypto/
│ │ ├── crypto_engine.dart
│ │ ├── native_crypto_engine.dart
│ │ ├── dart_crypto_fallback.dart
│ │ ├── encrypted_file_format.dart
│ │ └── key_manager.dart
│ ├── storage/
│ │ ├── file_blob_store.dart
│ │ ├── temporary_file_store.dart
│ │ └── storage_reconciler.dart
│ ├── archive/
│ │ ├── streaming_zip_reader.dart
│ │ └── streaming_zip_writer.dart
│ └── secure_storage/
│ └── platform_credential_repository.dart
│
├── platform/
│ ├── android/
│ │ ├── android_document_source.dart
│ │ ├── android_reader_bridge.dart
│ │ ├── android_thermal_monitor.dart
│ │ └── android_crypto_bridge.dart
│ ├── windows/
│ │ ├── windows_folder_source.dart
│ │ ├── windows_reader_bridge.dart
│ │ └── windows_crypto_bridge.dart
│ └── shared/
│ └── picked_source.dart
│
└── presentation/
├── controllers/
│ ├── auth_controller.dart
│ ├── vault_browser_controller.dart
│ ├── import_controller.dart
│ ├── export_controller.dart
│ └── reader_controller.dart
├── desktop/
│ └── desktop_shell.dart
├── mobile/
│ └── mobile_shell.dart
├── shared/
│ ├── vault_browser_view.dart
│ ├── operation_progress_view.dart
│ └── error_view.dart
└── widgets/
Important refinement

Do not create hundreds of tiny “use case” files simply to claim Clean Architecture. Split code where responsibilities or testing boundaries genuinely differ.

A good practical target is:

Widgets render and forward user actions.
Controllers hold observable UI state.
Application coordinators orchestrate workflows.
Domain interfaces define required capabilities.
Infrastructure classes perform database, filesystem, crypto and platform operations.
3. Runtime dependency rule

Dependencies should point inward:

Plain Text
Presentation
|
v
Application
|
v
Domain interfaces and entities
^
|
Infrastructure implementations

The domain layer must not import:

Flutter widgets.
Isar collections.
MethodChannel.
dart:io filesystem implementations.
Archive packages.
Platform-specific classes.

Dependency injection connects the infrastructure implementations during startup.

For this application, constructor injection is sufficient. You do not need a complicated service locator.

4. Security redesign
Current security problem

The documents state that the master AES key is stored separately from the password and that password reset retains the same master key. Therefore, the password currently acts mainly as a UI unlock gate rather than being cryptographically required to recover the vault key.

That should be the first architectural security correction.

Recommended key hierarchy
Plain Text
User password
|
| Argon2id or calibrated PBKDF2
v
KEK: Key Encryption Key
|
| authenticated key wrapping
v
DEK: random 256-bit vault Data Encryption Key
|
+---- encrypts per-file keys or files

Persist:

Plain Text
vault_version
kdf_algorithm
kdf_salt
kdf_parameters
wrapped_dek
wrapped_dek_nonce
wrapped_dek_authentication_tag
password_verifier, only if explicitly required

Keep only while unlocked:

Plain Text
unwrapped DEK
active session identifier
session timestamps

Clear the in-memory key when:

The user locks the vault.
The session expires.
The app backgrounds beyond the configured grace period.
The process is shutting down, where best-effort clearing is possible.

OWASP currently recommends Argon2id as the preferred password-storage algorithm and provides minimum parameters, but those values should be treated as a security floor rather than copied blindly into a mobile vault. The app should benchmark and calibrate its KDF on the target devices.

Password changes

Changing a password should:

Unwrap the existing DEK using the old password-derived KEK.
Derive a new KEK.
Rewrap only the DEK.
Atomically replace the key envelope.

You should not need to re-encrypt every vault file when the password changes.

Password reset

A true forgotten-password reset cannot preserve access without an additional recovery secret.

You must choose one clearly documented policy:

Secure policy
No password means no vault recovery.
Recovery key can restore access if enabled.
Security questions are not enough to recover high-value encrypted data.
Convenience policy
A recovery key protected by the OS keystore can unwrap the DEK.
This is explicitly described as device-assisted recovery.
Copying only the encrypted vault to another device still requires the password or exported recovery key.

Do not advertise the present security-question mechanism as cryptographic recovery unless it actually protects a valid DEK-recovery secret.

5. Encrypted file format

I would not keep raw AES-CTR blobs as the long-term format unless you add an authenticated MAC and formally specify the construction.

A better design is a versioned, chunk-authenticated file format.

Plain Text
[File header]
magic 8 bytes
format_version integer
algorithm_id integer
chunk_size integer
original_size integer
file_id 128-bit random value
base_nonce algorithm-specific
encrypted_metadata optional
header_authentication tag/MAC
 
[Chunk 0]
ciphertext
authentication tag
 
[Chunk 1]
ciphertext
authentication tag
 
...
 
[Final chunk]
ciphertext
authentication tag
Why chunked AEAD is appropriate
Files never need to be loaded fully into RAM.
Corruption is detected.
Import can report byte-accurate progress.
Decryption can be cancelled between chunks.
A damaged chunk does not make corruption invisible.
Future random-access viewers are possible.
Interrupted writes can be detected and discarded.
Nonce rule

Every encrypted chunk must have a unique nonce under the same key.

A safe design is:

Plain Text
nonce = random_file_nonce_prefix || chunk_counter

The exact construction must match the cryptographic library’s nonce requirements. Do not invent a nonce layout independently for each platform.

Metadata privacy

The documents confirm that originalName is currently plaintext in Isar despite claims that names are encrypted.

I recommend this staged policy:

Phase 1

Keep operational metadata in Isar but update the product claim:

Blob contents encrypted.
Database metadata not fully encrypted.
Phase 2

Add:

Plain Text
encrypted_name
name_nonce
name_tag
normalised_name_hash

A keyed search token could support exact or prefix-indexed searches, but this adds complexity and can leak search patterns. For a purely local application, the simpler approach is to decrypt names after unlock and maintain an in-memory search index for the session.

6. Native cryptography design
Do not make native crypto a blocking MethodChannel call

Moving Dart orchestration to an isolate does not automatically guarantee that a native plugin performs its work on a background native thread. Design the native implementation itself as asynchronous and threaded.

Preferred interface:

Dart
abstract interface class CryptoEngine {
Stream<CryptoProgress> encryptFile({
required String sourcePath,
required String destinationPath,
required SecretBytes key,
required EncryptionOptions options,
required CancellationToken cancellationToken,
});
 
Stream<CryptoProgress> decryptFile({
required String sourcePath,
required String destinationPath,
required SecretBytes key,
required CancellationToken cancellationToken,
});
 
Future<KeyDerivationResult> deriveKey(
KeyDerivationRequest request,
);
}

The returned stream should carry:

Dart
sealed class CryptoProgress {}
 
final class CryptoStarted extends CryptoProgress {
final int totalBytes;
}
 
final class CryptoBytesProcessed extends CryptoProgress {
final int processedBytes;
final int totalBytes;
}
 
final class CryptoCompleted extends CryptoProgress {
final CryptoOutput output;
}
Platform backend
Windows

Use a reviewed native cryptographic backend capable of:

Hardware-accelerated AES.
Authenticated encryption.
Streaming file processing.
Secure random generation.
Background worker execution.
Cancellation.
Android

Use a native backend with:

Authenticated encryption.
Buffered file or descriptor processing.
Background executor/thread.
Content URI/file descriptor support where needed.
Cancellation and progress callbacks.

The OS keystore is valuable for protecting wrapping keys and recovery material, but that does not mean every large media byte must pass through a keystore API.

Dart fallback

Retain a Dart implementation for:

Tests.
Migration verification.
Unsupported environments.
Small data where native functionality is unavailable.

It should not be the preferred production bulk-file backend.

7. One unified import pipeline

Delete the conceptual separation between desktop import, mobile import, ZIP import and folder-container import at the execution layer.

They differ only in their source adapters.

Plain Text
Windows folder picker ─┐
Android SAF tree ──────┤
Selected files ────────┤
ZIP archive ───────────┼─> SourceEnumerator
Shared item ───────────┤
v
Validate and plan
|
v
Job Scheduler
|
v
Read source item as bounded stream
|
v
Encrypt to temporary blob
|
v
Verify output and authentication
|
v
Atomic blob move + Isar metadata commit
|
v
Update running storage total
Import invariants

For every file:

Metadata must never point to a missing final blob.
A final blob must not lack corresponding metadata indefinitely.
A partially written file must use a temporary extension.
Temporary blobs must be recoverable or removable after restart.
Cancellation must stop at a known checkpoint.
Duplicate handling must follow an explicit policy.
Unsupported files must be reported, not silently skipped.
Per-file commit protocol
Plain Text
1. Create database job-item record: pending
2. Encrypt source to <blob-id>.partial
3. Flush and close output
4. Verify authenticated header and final chunk
5. Rename .partial to .vault
6. In one Isar transaction:
- Insert VaultFile metadata
- Mark job item complete
- Update totalBytesUsed

After a crash:

.partial + pending job means resume or clean up.
Final blob + pending metadata means reconcile.
Metadata + absent blob means mark damaged and report it.

This matters more for reliability than merely adding more isolates.

8. Job engine

The existing long-running operations are started by UI flows and lack a unified cancellation, pause, resume and recovery mechanism.

Create persistent OperationJob and OperationJobItem records.

Dart
enum JobType {
import,
export,
decryptForViewer,
migrateEncryption,
verifyIntegrity,
}
 
enum JobState {
queued,
running,
pausing,
paused,
cancelling,
cancelled,
completed,
failed,
interrupted,
}

Each job should store:

Plain Text
id
type
state
createdAt
startedAt
completedAt
totalItems
completedItems
totalBytes
processedBytes
currentItem
sourceDescriptor
destinationDescriptor
failureCode
retryCount
resumeData
Scheduler rules
Android profile
One heavy crypto job at a time.
One large file actively encrypted at a time.
Small metadata operations may be batched.
Reduce work under thermal pressure.
Never skip a file because the device is warm.
Pause or reduce concurrency, then resume.
Windows profile
Start conservatively with two concurrent file operations.
Benchmark two, three and four workers.
Restrict large-video concurrency.
Let measured disk and CPU throughput determine the final setting.

Android provides thermal status and headroom APIs that applications can use to adjust workload. Thermal control should therefore be based on actual platform readings, not hardcoded battery or thermal values.

9. ZIP architecture

The current readAsBytes() archive path must be removed for large archives because your documents identify full-archive RAM loading as a critical OOM and responsiveness risk.

Use:

Plain Text
Open archive
|
Read central directory/index where format requires it
|
For each accepted entry:
|
Validate path
|
Stream entry into a bounded temporary file or crypto input
|
Encrypt
|
Delete plaintext temporary entry
ZIP security checks

Every entry must be checked for:

../ traversal.
Absolute paths.
Invalid filenames.
Symbolic-link handling.
Duplicate output paths.
Excessive expanded size.
Excessive entry count.
Suspicious compression ratio.
Encrypted-entry support.
Cancellation.

Never trust the internal archive path.

Password-protected ZIP files

Treat password-ZIP support as a source-decoding concern, not as vault security.

The vault’s encryption begins after the archive entry has been decoded. If the chosen archive library cannot stream password-protected entries safely and efficiently, isolate that limitation behind ArchiveReader instead of allowing it to distort the entire import architecture.

10. Export architecture

Preferred flow:

Plain Text
Vault query
|
Folder/path mapper
|
For each file:
|
Decrypt bounded chunks
|
Write directly to current ZIP entry
|
Finalise entry
|
Continue

This avoids staging the entire plaintext selection.

If the archive writer cannot accept a streaming entry, use a bounded temporary-file fallback:

Plain Text
decrypt one file
|
add one file to archive
|
delete plaintext immediately

Never decrypt the complete vault before starting archive generation.

For external manga readers, staging is sometimes unavoidable. Limit it to:

The selected chapter.
The selected folder.
A configured cache budget.

Do not expand the complete library by default.

11. State management

Either Riverpod or Bloc can work. For this project, I recommend Riverpod, primarily because it fits constructor-injected repositories, asynchronous state and shared desktop/mobile controllers with relatively little boilerplate.

The important rule is not the package. The important rule is that widgets stop constructing services directly.

Example controller boundary:

Dart
final class ImportState {
final JobState status;
final int processedBytes;
final int totalBytes;
final String? currentItem;
final AppFailure? failure;
}
Dart
final class ImportController {
ImportController(
this._createImportPlan,
this._jobScheduler,
);
 
final CreateImportPlan _createImportPlan;
final JobScheduler _jobScheduler;
 
Future<void> start(ImportRequest request) async {
// Validate input, create a job and observe its state.
}
 
Future<void> pause() async {}
Future<void> resume() async {}
Future<void> cancel() async {}
}

The desktop and mobile screens consume the same ImportState.

12. UI design
Shared interface

Both platforms should share:

Vault folder/file view.
Selection model.
Search state.
Sort and filter rules.
Import/export status.
Rename/move/delete commands.
Error presentation model.
Empty states.
Storage usage display.
Desktop shell

Use:

Navigation rail or folder pane.
Main file grid/list.
Details or job panel.
Context menus.
Drag-and-drop import later.
Keyboard navigation and shortcuts.
Persistent operation queue.

Suggested layout:

Plain Text
+----------------------------------------------------------+
| App bar: Vault | Search | Storage | Lock | Settings |
+-------------+--------------------------------+-----------+
| Folder tree | File/folder browser | Details |
| | | / Jobs |
| | | panel |
+-------------+--------------------------------+-----------+
| Active job progress / warnings / cancellation |
+----------------------------------------------------------+
Mobile shell

Use:

Top app bar.
Shared browser body.
Bottom navigation only if there are genuinely separate destinations.
Contextual selection app bar.
FAB or bottom sheet for import actions.
Full-screen job details for long operations.
Persistent compact progress indicator while navigating.

Avoid embedding workflow code in dialogs. Dialogs should only collect input and call controllers.

13. Database design changes

Add these collections or equivalents:

Plain Text
VaultFile
VaultFolder
OperationJob
OperationJobItem
VaultConfiguration
StorageCounter
SchemaMigration
IntegrityRecord, optional
Revised VaultFile
Plain Text
id
folderId
blobId
encryptedName
nameNonce
nameTag
mimeCategory
originalSize
encryptedSize
formatVersion
createdAt
modifiedAt
sortOrder
integrityState
importJobId

Avoid storing the master key, derived KEK or decrypted names in Isar.

Storage accounting

Replace findAll() and summation with a transactional counter:

Plain Text
storedBlobBytes
estimatedPlaintextBytes
temporaryBytes
lastReconciledAt

Update it in the same logical commit that creates or deletes file metadata.

Also run a low-priority reconciliation operation after:

Abnormal shutdown.
Schema migration.
Manual repair.
Detected counter mismatch.
Indexes

Add indexes based on actual query patterns:

folderId
parentId
blobId
importJobId
createdAt
Search token, if encrypted-name search is implemented

Do not add an index merely because a field exists.

14. Error design

Do not pass arbitrary exceptions directly to widgets.

Use typed failures:

Dart
sealed class AppFailure {
const AppFailure();
}
 
final class InsufficientStorageFailure extends AppFailure {}
 
final class AuthenticationFailure extends AppFailure {}
 
final class CorruptEncryptedFileFailure extends AppFailure {
final String fileId;
}
 
final class UnsupportedArchiveFailure extends AppFailure {}
 
final class PermissionRevokedFailure extends AppFailure {}
 
final class OperationCancelledFailure extends AppFailure {}

Every error should carry:

Stable internal error code.
User-safe message.
Debug context without secrets.
Retryability.
Recommended recovery action.

Never log:

User passwords.
Derived keys.
Master keys.
Decrypted paths when privacy mode is enabled.
Raw secure-storage values.
15. What should be deleted or quarantined

Based on the documents, I would remove from production wiring:

Placeholder IsolateCryptoService.
Fake battery values.
Fake memory-pressure checks.
Dummy-list “garbage collection”.
Unused hardware multipliers.
Artificial import delays.
In-memory container encryption as a default.
Duplicate enhanced/basic repositories.
UI-specific import implementations.
Any service whose name claims acceleration but does not change execution.

These are explicitly described as placeholders, stubs or ineffective paths in the current analysis.

Do not immediately delete every file. First:

Mark it deprecated.
Remove callers.
Add tests around the replacement.
Delete it after the new pipeline is active.
16. Migration sequence
Phase 0: Establish measurements

Before altering cryptography:

Measure unlock duration.
Measure MB/s for import and export.
Record peak RSS.
Record frame build/raster times.
Record temporary disk usage.
Test the same fixed datasets on both devices.

Do not treat the throughput estimates in the documents as measured results. The documents themselves label a number of them as rough or expected figures.

Phase 1: Correctness and immediate responsiveness
Move PBKDF2 computation away from the UI isolate.
Remove artificial delays.
Introduce transactional totalBytesUsed.
Fix thermal pauses so they wait instead of skipping files.
Include all supported media types in desktop imports.
Add typed failures.
Add structured job progress based on bytes.
Disable the placeholder crypto service.

This gives relatively low-risk improvement without changing the encrypted format.

Phase 2: Extract application logic
Introduce repository interfaces.
Extract ImportCoordinator.
Extract ExportCoordinator.
Add persistent jobs.
Make both shells call the same coordinators.
Split the god screens into shared browser components.
Add cancellation and restart recovery.

At the end of this phase, old and new encryption can still coexist.

Phase 3: Streaming archive processing
Introduce ArchiveReader.
Implement path validation.
Process one entry at a time.
Remove full ZIP readAsBytes().
Delete each temporary plaintext entry immediately.
Stream export entries where supported.

This specifically addresses the highest mobile OOM risk identified in the supplied documents.

Phase 4: Versioned cryptographic format
Finalise and document the new file format.
Implement the Dart reference backend.
Add known-answer tests.
Implement Windows native backend.
Implement Android native backend.
Cross-test ciphertext compatibility.
Add tamper and truncation tests.
Benchmark on release builds.
Phase 5: Password-wrapped DEK
Introduce the key envelope.
On successful legacy login, obtain the current DEK.
Derive the new KEK.
Wrap the existing DEK.
Persist the envelope atomically.
Keep a rollback marker until verification succeeds.
Remove legacy key storage only after successful migration.

This avoids immediately re-encrypting all existing files.

Phase 6: Incremental blob migration

When an old-format file is opened or during an explicit background migration:

Plain Text
legacy blob
|
decrypt through legacy reader
|
encrypt through new writer
|
verify
|
atomic replace
|
update formatVersion

Allow the vault to contain mixed format versions during migration.

Phase 7: Metadata privacy and polish
Encrypt names.
Add in-memory unlocked-session search.
Introduce real thermal monitoring.
Add optional biometric/device-assisted unlock.
Improve external-reader cache TTL.
Delete deprecated services.
Correct README security and performance claims.
17. Testing architecture
Unit tests

Test:

KDF parameter serialisation.
Key wrapping and unwrapping.
Wrong-password behaviour.
Nonce generation and uniqueness.
Chunk header parsing.
Authentication failure.
Path normalisation.
Import-plan creation.
Duplicate handling.
Storage-counter updates.
Job state transitions.
Cross-platform crypto tests

The Android and Windows implementations must pass the same vectors:

Plain Text
empty file
1 byte
chunk size - 1
exact chunk size
chunk size + 1
large media file
tampered header
tampered middle chunk
truncated final chunk
wrong key
cancel halfway

Encrypting on Windows and decrypting on Android must work, and vice versa, if vault portability is a goal.

Crash-recovery tests

Terminate the process during:

Temporary blob creation.
Blob finalisation.
Database transaction.
ZIP entry extraction.
Export finalisation.
Legacy-format migration.

Then verify that restart recovery leaves no invisible loss or orphaned final data.

Performance tests

Use fixed datasets:

Plain Text
Dataset A: 1,000 small images
Dataset B: one 1 GB video
Dataset C: 500 MB ZIP with many entries
Dataset D: mixed 1 GB library
Dataset E: deeply nested manga tree

Measure:

Total duration.
Median and p95 per-file latency.
MB/s.
Peak RSS.
Temporary disk usage.
Dropped/flutter-janky frames.
Cancellation latency.
Thermal status.
Battery delta on Android.
18. Realistic acceptance criteria

Some existing proposed targets, such as fixed native throughput or sub-400 ms unlock, should be treated as goals rather than guaranteed acceptance criteria until measured on release builds. KDF latency intentionally represents security work, so making it arbitrarily fast can weaken password-guessing resistance.

Use these acceptance conditions instead:

Correctness
Wrong credentials never expose the DEK.
Bit modification is detected before corrupted plaintext is accepted.
Cancelled import does not create a visible partial file.
No file is skipped silently.
Crash recovery produces a deterministic result.
Storage totals remain consistent.
Responsiveness
No CPU-heavy cryptography runs on the UI isolate.
Progress is updated from real byte counts.
Navigation remains usable during import.
Cancellation is acknowledged within a bounded chunk boundary.
ZIP memory usage does not scale linearly with total archive size.
Mobile stability
A 500 MB valid ZIP completes without loading the whole archive.
One large file import does not require an equally large Uint8List.
Thermal pressure pauses or reduces work rather than dropping items.
Temporary plaintext remains bounded.
Desktop scalability
Worker count is configurable by measured policy.
Large files do not run with uncontrolled concurrency.
Import and export continue to report progress.
Interrupting the app leaves recoverable job state.
19. Final architectural decisions

These are the decisions I recommend locking in:

Flutter remains the shared UI framework.
Isar remains the metadata store during this redesign.
Riverpod manages presentation state and dependency exposure.
One shared import/export job engine serves both platforms.
Individual encrypted blobs remain the primary storage unit.
The container strategy is removed from normal imports.
New blobs use a versioned, chunk-authenticated format.
The password-derived KEK wraps the random vault DEK.
Large crypto operations execute in native background workers.
Dart isolates handle suitable Dart computation and coordination, not giant memory copies.
ZIP processing is streaming and bounded.
Jobs are persistent, resumable, cancellable and reconciled after crashes.
Desktop and mobile have separate shells but shared business logic.
Metadata privacy is stated honestly, then improved through a versioned migration.
Every performance claim is backed by release-mode measurement.
Bottom line

Your application does not need more optimisation services. It needs fewer execution paths and stronger invariants.

The highest-value design is:

Plain Text
Thin platform UI
+
Shared application controllers
+
One persistent job engine
+
Streaming bounded I/O
+
Versioned authenticated encryption
+
Password-wrapped vault key
+
Native asynchronous crypto

That architecture directly addresses the security mismatch, UI freezes, archive memory risk, duplicated platform logic, unreliable cancellation and difficult future maintenance identified in ARCHITECTURE_AND_DESIGN and BUGS_PERFORMANCE_AND_IMPROVEMENTS.