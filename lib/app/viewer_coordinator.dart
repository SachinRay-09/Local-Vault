// TODO(Phase-3): Implement ViewerCoordinator for in-app viewing pipeline.
// See design §2.2 — ViewerCoordinator decrypts a VaultFile to a temp path,
// opens the appropriate viewer widget, and cleans up the temp file when the
// viewer closes.  For now each viewer screen decrypts inline via
// VaultOpenService / FileCryptoService.
