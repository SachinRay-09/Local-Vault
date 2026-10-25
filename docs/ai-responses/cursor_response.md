Wrote WORKFLOWS_CRASHES_AND_PLAN_MATCH.md. It traces each flow at UI, CPU, disk, and process level, names crash/OOM/freeze causes, and scores them against the verified architecture.

There is no OS background service. Everything runs in one Flutter process (UI isolate doing almost all crypto today) plus separate apps (Yomikiru / Mihon) after a plaintext dump.

1. Open / password / freeze / recovery
First launch: engine → Isar in app-support → no password → setup (create 32-byte master key in OS secure storage + PBKDF2 password hash + SHA-256 security answers).

Unlock freeze is 120,000 PointyCastle PBKDF2 iterations on the UI isolate — AES-NI/ARM crypto unused. Spinner often cannot animate. Wrong password only bumps lockout (30s / 2m / 5m). Questions reset the password hash only; the encryption key stays. Forgot both: no recovery today. After a real KEK/DEK wrap, that becomes permanent loss unless you add a recovery key (must be a spec decision so libraries are not bricked).

2. After unlock — folders
Create / rename / move only change Isar parentId / name. Blobs do not move. Cheap and safe on both devices.

3. Import / export
PC export: decrypt everything to %TEMP% staging → ZIP → delete staging. Heavy, but the right PC → phone path.

PC import folder: images only, batches of 3 + 100 ms delay, AES on UI thread.

ZIP (PC and phone): often readAsBytes() of the whole archive — main OOM kill on the 6 GB Z9x.

New plan (stream ZIP, one job, no container-in-RAM) is what makes import viable on the phone.

4. Secure storage
Pages: AES-256-CTR blobs under app-private vault_blobs. Names/folders: plaintext Isar. Key: OS Credential Manager / Android Keystore not wrapped by your password. Password is a UI gate until Phase 5 of the plan.

5. Mihon / Yomikiru and the Clean Up dialog
Windows: %TEMP%\local_vault_yomikiru\<folder>\
Android: /storage/emulated/0/Manga/LocalVault/manga_temp/<folder>/ (shared so Mihon can read)
If you only switch apps and Local Vault stays in memory, the dialog stays. If Android kills the process, the dialog is gone (nothing persisted).
Windows top-bar Clear temp does remove Yomikiru temps.
Android top-bar Clear temp does not remove Manga/LocalVault — only the dialog Clean Up (or a file manager) does. The new plan’s leftover-plaintext job is what fixes that.

6. Clear temp vs other files
Checked in AppLifecycleService: it does not delete vault_blobs or Isar, and it does not walk DCIM/Downloads. It deletes app temp/cache and dirs under OS/app temp whose names match vault / yomikiru / local_vault_*. Safe for your library; incomplete for Mihon plaintext; slightly loose name-matching in %TEMP%. Plan: allowlist only folders this app created.