#pragma once
#include <flutter/binary_messenger.h>

/// Registers the local_vault/crypto_native MethodChannel with BCrypt/CNG
/// AES-256-GCM implementation for v1 blobs.
void RegisterCryptoBridge(flutter::BinaryMessenger* messenger);
