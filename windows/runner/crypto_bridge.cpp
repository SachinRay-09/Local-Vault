// crypto_bridge.cpp
// Windows BCrypt/CNG AES-256-GCM implementation for LVCRYPT1 v1 blobs.
// MethodChannel: local_vault/crypto_native
//   encryptFile(sourcePath, destPath, keyBase64) → Map{byteSize}
//   decryptFile(sourcePath, destPath, keyBase64)  → void
// v0 blobs are NOT handled here — the Dart layer detects v0 and routes to DartCryptoEngine.

#include "crypto_bridge.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <bcrypt.h>

// STATUS_SUCCESS is 0 — define it here to avoid the macro redefinition
// storm caused by including <ntstatus.h> alongside <windows.h>.
#ifndef STATUS_SUCCESS
#  define STATUS_SUCCESS ((NTSTATUS)0x00000000L)
#endif

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/binary_messenger.h>

#include <cassert>
#include <cstring>
#include <fstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#pragma comment(lib, "bcrypt.lib")

// ─── Constants ───────────────────────────────────────────────────────────────
static constexpr size_t   kChunkSize      = 524288;   // 512 KB
static constexpr size_t   kGcmTagSize     = 16;
static constexpr size_t   kHeaderRawSize  = 60;
static constexpr size_t   kHeaderTotalSize = 76;       // 60 + 16

static const uint8_t kMagic[8] = {'L','V','C','R','Y','P','T','1'};

// ─── Byte-order helpers ───────────────────────────────────────────────────────

static void write_u16_be(uint8_t* buf, uint16_t v) {
  buf[0] = (v >> 8) & 0xFF;
  buf[1] =  v       & 0xFF;
}

static void write_u32_be(uint8_t* buf, uint32_t v) {
  buf[0] = (v >> 24) & 0xFF;
  buf[1] = (v >> 16) & 0xFF;
  buf[2] = (v >>  8) & 0xFF;
  buf[3] =  v        & 0xFF;
}

static void write_u64_be(uint8_t* buf, uint64_t v) {
  for (int i = 7; i >= 0; --i) { buf[i] = v & 0xFF; v >>= 8; }
}

static uint32_t read_u32_be(const uint8_t* buf) {
  return ((uint32_t)buf[0] << 24) | ((uint32_t)buf[1] << 16)
       | ((uint32_t)buf[2] <<  8) |  (uint32_t)buf[3];
}

static uint64_t read_u64_be(const uint8_t* buf) {
  uint64_t v = 0;
  for (int i = 0; i < 8; ++i) v = (v << 8) | buf[i];
  return v;
}

// ─── Nonce construction ───────────────────────────────────────────────────────
// base_nonce[0..7] random; bytes [8..11] = uint32_be(chunkIndex)
static void build_chunk_nonce(const uint8_t* base_nonce, uint32_t index,
                               uint8_t out[12]) {
  memcpy(out, base_nonce, 12);
  out[8]  = (index >> 24) & 0xFF;
  out[9]  = (index >> 16) & 0xFF;
  out[10] = (index >>  8) & 0xFF;
  out[11] =  index        & 0xFF;
}

// ─── BCrypt random bytes ──────────────────────────────────────────────────────
static void secure_random(uint8_t* buf, size_t len) {
  BCRYPT_ALG_HANDLE hRng = nullptr;
  BCryptOpenAlgorithmProvider(&hRng, BCRYPT_RNG_ALGORITHM, nullptr, 0);
  BCryptGenRandom(hRng, buf, static_cast<ULONG>(len), 0);
  BCryptCloseAlgorithmProvider(hRng, 0);
}

// ─── BCrypt AES-GCM context ───────────────────────────────────────────────────
struct AesGcmCtx {
  BCRYPT_ALG_HANDLE hAlg  = nullptr;
  BCRYPT_KEY_HANDLE hKey  = nullptr;
  std::vector<uint8_t> keyObj;

  AesGcmCtx() = default;
  AesGcmCtx(const AesGcmCtx&) = delete;
  AesGcmCtx& operator=(const AesGcmCtx&) = delete;
  AesGcmCtx(AesGcmCtx&& o) noexcept
      : hAlg(o.hAlg), hKey(o.hKey), keyObj(std::move(o.keyObj)) {
    o.hAlg = nullptr;
    o.hKey = nullptr;
  }
  AesGcmCtx& operator=(AesGcmCtx&&) = delete;

  ~AesGcmCtx() {
    if (hKey)  BCryptDestroyKey(hKey);
    if (hAlg)  BCryptCloseAlgorithmProvider(hAlg, 0);
  }
};

static AesGcmCtx open_aes_gcm(const uint8_t* key32) {
  AesGcmCtx ctx;
  BCryptOpenAlgorithmProvider(&ctx.hAlg, BCRYPT_AES_ALGORITHM, nullptr, 0);

  const wchar_t* gcm = BCRYPT_CHAIN_MODE_GCM;
  BCryptSetProperty(ctx.hAlg, BCRYPT_CHAINING_MODE,
      reinterpret_cast<PUCHAR>(const_cast<wchar_t*>(gcm)),
      static_cast<ULONG>((wcslen(gcm) + 1) * sizeof(wchar_t)), 0);

  ULONG objLen = 0, resultLen = 0;
  BCryptGetProperty(ctx.hAlg, BCRYPT_OBJECT_LENGTH,
      reinterpret_cast<PUCHAR>(&objLen), sizeof(ULONG), &resultLen, 0);
  ctx.keyObj.resize(objLen);

  BCryptGenerateSymmetricKey(ctx.hAlg, &ctx.hKey,
      ctx.keyObj.data(), objLen,
      const_cast<PUCHAR>(key32), 32, 0);
  return ctx;
}

// ─── GCM encrypt one block ────────────────────────────────────────────────────
// output must have capacity plainLen + kGcmTagSize.
static void gcm_encrypt(AesGcmCtx& ctx,
                         const uint8_t nonce[12],
                         const uint8_t* aad, size_t aadLen,
                         const uint8_t* plain, size_t plainLen,
                         uint8_t* out) {
  uint8_t tag[kGcmTagSize] = {};

  BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO ai;
  BCRYPT_INIT_AUTH_MODE_INFO(ai);
  ai.pbNonce    = const_cast<PUCHAR>(nonce);
  ai.cbNonce    = 12;
  ai.pbTag      = tag;
  ai.cbTag      = static_cast<ULONG>(kGcmTagSize);
  ai.pbAuthData = (aadLen > 0) ? const_cast<PUCHAR>(aad) : nullptr;
  ai.cbAuthData = static_cast<ULONG>(aadLen);

  ULONG written = 0;
  if (plainLen > 0) {
    BCryptEncrypt(ctx.hKey, const_cast<PUCHAR>(plain), static_cast<ULONG>(plainLen),
        &ai, nullptr, 0, out, static_cast<ULONG>(plainLen), &written, 0);
  } else {
    // Empty plaintext — BCrypt still produces the tag
    BCryptEncrypt(ctx.hKey, nullptr, 0,
        &ai, nullptr, 0, nullptr, 0, &written, 0);
  }
  memcpy(out + plainLen, tag, kGcmTagSize);
}

// ─── GCM decrypt one block ────────────────────────────────────────────────────
// Returns false on tag mismatch.
// [cipherAndTag] must point to a buffer of at least cipherLen + kGcmTagSize bytes.
// [cipherLen] is the number of ciphertext bytes (NOT including the tag).
// The tag occupies cipherAndTag[cipherLen .. cipherLen+kGcmTagSize-1].
static bool gcm_decrypt(AesGcmCtx& ctx,
                         const uint8_t nonce[12],
                         const uint8_t* aad, size_t aadLen,
                         const uint8_t* cipherAndTag, size_t cipherLen,
                         uint8_t* out) {
  // Named pointer to make the offset arithmetic explicit and auditable.
  // Callers must ensure the backing buffer is at least cipherLen+kGcmTagSize bytes.
  const uint8_t* const tagPtr = cipherAndTag + cipherLen;

  BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO ai;
  BCRYPT_INIT_AUTH_MODE_INFO(ai);
  ai.pbNonce    = const_cast<PUCHAR>(nonce);
  ai.cbNonce    = 12;
  ai.pbTag      = const_cast<PUCHAR>(tagPtr);
  ai.cbTag      = static_cast<ULONG>(kGcmTagSize);
  ai.pbAuthData = (aadLen > 0) ? const_cast<PUCHAR>(aad) : nullptr;
  ai.cbAuthData = static_cast<ULONG>(aadLen);

  ULONG written = 0;
  NTSTATUS st = BCryptDecrypt(ctx.hKey,
      const_cast<PUCHAR>(cipherAndTag), static_cast<ULONG>(cipherLen),
      &ai, nullptr, 0, out, static_cast<ULONG>(cipherLen), &written, 0);
  return st == STATUS_SUCCESS;
}

// ─── v1 Header auth tag: GCM over empty plaintext with AAD=header ─────────────
// Calls BCrypt directly (same pattern as verify_header_tag) to avoid routing
// through gcm_encrypt with a tag-sized output buffer that would overflow for
// any non-zero plainLen.
// Sentinel index 0xFFFFFFFF ensures the header tag nonce never collides with
// any data chunk nonce (chunk 0 uses index 0x00000000).
static void compute_header_tag(AesGcmCtx& ctx,
                                const uint8_t* base_nonce,
                                const uint8_t header[kHeaderRawSize],
                                uint8_t out_tag[kGcmTagSize]) {
  uint8_t nonceHdr[12];
  build_chunk_nonce(base_nonce, 0xFFFFFFFFu, nonceHdr);

  BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO ai;
  BCRYPT_INIT_AUTH_MODE_INFO(ai);
  ai.pbNonce    = nonceHdr;
  ai.cbNonce    = 12;
  ai.pbTag      = out_tag;           // BCrypt writes the tag directly here
  ai.cbTag      = static_cast<ULONG>(kGcmTagSize);
  ai.pbAuthData = const_cast<PUCHAR>(header);
  ai.cbAuthData = static_cast<ULONG>(kHeaderRawSize);

  // Encrypt empty plaintext: no ciphertext written, tag lands in out_tag.
  ULONG written = 0;
  BCryptEncrypt(ctx.hKey, nullptr, 0, &ai,
                nullptr, 0, nullptr, 0, &written, 0);
}

// ─── Verify header auth tag ───────────────────────────────────────────────────
static bool verify_header_tag(AesGcmCtx& ctx,
                               const uint8_t* base_nonce,
                               const uint8_t header[kHeaderRawSize],
                               const uint8_t tag[kGcmTagSize]) {
  uint8_t nonceHdr[12];
  // Sentinel 0xFFFFFFFF matches compute_header_tag — must be identical.
  build_chunk_nonce(base_nonce, 0xFFFFFFFFu, nonceHdr);

  BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO ai;
  BCRYPT_INIT_AUTH_MODE_INFO(ai);
  ai.pbNonce    = nonceHdr;
  ai.cbNonce    = 12;
  ai.pbTag      = const_cast<PUCHAR>(tag);
  ai.cbTag      = static_cast<ULONG>(kGcmTagSize);
  ai.pbAuthData = const_cast<PUCHAR>(header);
  ai.cbAuthData = static_cast<ULONG>(kHeaderRawSize);

  ULONG written = 0;
  NTSTATUS st = BCryptDecrypt(ctx.hKey, nullptr, 0, &ai,
                              nullptr, 0, nullptr, 0, &written, 0);
  return st == STATUS_SUCCESS;
}

// ─── Minimal base64 decode (for key bytes) ───────────────────────────────────
static std::vector<uint8_t> base64_decode(const std::string& encoded) {
  static const std::string chars =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::vector<uint8_t> out;
  out.reserve(encoded.size() * 3 / 4);
  int val = 0, bits = -8;
  for (unsigned char c : encoded) {
    if (c == '=') break;
    auto pos = chars.find(static_cast<char>(c));
    if (pos == std::string::npos) continue;
    val = (val << 6) + static_cast<int>(pos);
    bits += 6;
    if (bits >= 0) {
      out.push_back(static_cast<uint8_t>((val >> bits) & 0xFF));
      bits -= 8;
    }
  }
  return out;
}

// ─── v1 Encrypt ──────────────────────────────────────────────────────────────
static int64_t encrypt_file_v1(const std::string& srcPath,
                                const std::string& dstPath,
                                const std::vector<uint8_t>& key) {
  std::ifstream src(srcPath, std::ios::binary | std::ios::ate);
  if (!src.is_open())
    throw std::runtime_error("Cannot open source: " + srcPath);
  const int64_t originalSize = static_cast<int64_t>(src.tellg());
  src.seekg(0);

  std::ofstream dst(dstPath, std::ios::binary | std::ios::trunc);
  if (!dst.is_open())
    throw std::runtime_error("Cannot open dest: " + dstPath);

  // Generate random file_id and base_nonce
  uint8_t fileId[16], baseNonce[12];
  secure_random(fileId, 16);
  secure_random(baseNonce, 12);

  // Build 60-byte header
  uint8_t header[kHeaderRawSize] = {};
  memcpy(header, kMagic, 8);
  write_u16_be(header + 8,  1);                            // format_version = 1
  write_u16_be(header + 10, 1);                            // algorithm_id = AES-256-GCM
  write_u32_be(header + 12, static_cast<uint32_t>(kChunkSize));
  write_u64_be(header + 16, static_cast<uint64_t>(originalSize));
  memcpy(header + 24, fileId,    16);
  memcpy(header + 40, baseNonce, 12);
  // [52..59] reserved, zeroed

  auto ctx = open_aes_gcm(key.data());

  // Compute header auth tag
  uint8_t headerTag[kGcmTagSize];
  compute_header_tag(ctx, baseNonce, header, headerTag);

  // Write header (60) + header_auth_tag (16)
  dst.write(reinterpret_cast<const char*>(header), kHeaderRawSize);
  dst.write(reinterpret_cast<const char*>(headerTag), kGcmTagSize);

  // Encrypt data chunks
  std::vector<uint8_t> plainBuf(kChunkSize);
  std::vector<uint8_t> cipherBuf(kChunkSize + kGcmTagSize);
  uint32_t chunkIdx = 0;

  while (src) {
    src.read(reinterpret_cast<char*>(plainBuf.data()), kChunkSize);
    const auto bytesRead = static_cast<size_t>(src.gcount());
    if (bytesRead == 0) break;

    uint8_t nonce[12];
    build_chunk_nonce(baseNonce, chunkIdx, nonce);
    gcm_encrypt(ctx, nonce, nullptr, 0, plainBuf.data(), bytesRead, cipherBuf.data());
    dst.write(reinterpret_cast<const char*>(cipherBuf.data()),
              static_cast<std::streamsize>(bytesRead + kGcmTagSize));
    chunkIdx++;
  }

  return originalSize;
}

// ─── v1 Decrypt ──────────────────────────────────────────────────────────────
static void decrypt_file_v1(const std::string& srcPath,
                              const std::string& dstPath,
                              const std::vector<uint8_t>& key) {
  std::ifstream src(srcPath, std::ios::binary);
  if (!src.is_open())
    throw std::runtime_error("Cannot open source: " + srcPath);

  // Read 60-byte header
  uint8_t header[kHeaderRawSize];
  src.read(reinterpret_cast<char*>(header), kHeaderRawSize);
  if (static_cast<size_t>(src.gcount()) < kHeaderRawSize)
    throw std::runtime_error("Truncated v1 header");

  // Validate magic
  if (memcmp(header, kMagic, 8) != 0)
    throw std::runtime_error("Invalid magic bytes");

  // Read 16-byte header auth tag
  uint8_t headerTag[kGcmTagSize];
  src.read(reinterpret_cast<char*>(headerTag), kGcmTagSize);
  if (static_cast<size_t>(src.gcount()) < kGcmTagSize)
    throw std::runtime_error("Truncated header auth tag");

  const uint8_t* baseNonce = header + 40;
  auto ctx = open_aes_gcm(key.data());

  // Verify header auth tag
  if (!verify_header_tag(ctx, baseNonce, header, headerTag))
    throw std::runtime_error("Header authentication failed");

  const uint32_t chunkSize    = read_u32_be(header + 12);
  const uint64_t originalSize = read_u64_be(header + 16);

  std::ofstream dst(dstPath, std::ios::binary | std::ios::trunc);
  if (!dst.is_open())
    throw std::runtime_error("Cannot open dest: " + dstPath);

  // Decrypt data chunks
  std::vector<uint8_t> inBuf(chunkSize + kGcmTagSize);
  std::vector<uint8_t> plainBuf(chunkSize);
  uint32_t chunkIdx = 0;

  while (src) {
    src.read(reinterpret_cast<char*>(inBuf.data()),
             static_cast<std::streamsize>(chunkSize + kGcmTagSize));
    const auto bytesRead = static_cast<size_t>(src.gcount());
    if (bytesRead == 0) break;

    if (bytesRead <= kGcmTagSize)
      throw std::runtime_error(
          "Truncated chunk " + std::to_string(chunkIdx) +
          " (only " + std::to_string(bytesRead) + " bytes)");

    const size_t cipherLen = bytesRead - kGcmTagSize;
    uint8_t nonce[12];
    build_chunk_nonce(baseNonce, chunkIdx, nonce);

    if (!gcm_decrypt(ctx, nonce, nullptr, 0,
                     inBuf.data(), cipherLen, plainBuf.data()))
      throw std::runtime_error(
          "Chunk " + std::to_string(chunkIdx) + " auth tag mismatch");

    dst.write(reinterpret_cast<const char*>(plainBuf.data()),
              static_cast<std::streamsize>(cipherLen));
    chunkIdx++;
  }

  // Sanity: verify decoded size
  (void)originalSize; // checked on Dart side; native just writes what it reads
}

// ─── MethodChannel registration ──────────────────────────────────────────────

void RegisterCryptoBridge(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger,
      "local_vault/crypto_native",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [channel](const flutter::MethodCall<flutter::EncodableValue>& call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

        // Capture result in shared_ptr so the background thread can resolve it.
        auto result_ptr = std::make_shared<
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>>(
            std::move(result));

        // Capture call arguments before the lambda runs on another thread.
        const std::string method_name = call.method_name();
        const auto& raw_args = *call.arguments();
        flutter::EncodableMap args;
        if (std::holds_alternative<flutter::EncodableMap>(raw_args)) {
          args = std::get<flutter::EncodableMap>(raw_args);
        }

        std::thread([method_name, args, result_ptr]() mutable {
          try {
            auto get_str = [&](const std::string& k) -> std::string {
              return std::get<std::string>(
                  args.at(flutter::EncodableValue(k)));
            };

            if (method_name == "encryptFile") {
              const auto src    = get_str("sourcePath");
              const auto dst    = get_str("destPath");
              const auto keyB64 = get_str("keyBase64");
              const auto key    = base64_decode(keyB64);
              const int64_t sz  = encrypt_file_v1(src, dst, key);

              flutter::EncodableMap resp;
              resp[flutter::EncodableValue("byteSize")] =
                  flutter::EncodableValue(sz);
              (*result_ptr)->Success(flutter::EncodableValue(resp));

            } else if (method_name == "decryptFile") {
              const auto src    = get_str("sourcePath");
              const auto dst    = get_str("destPath");
              const auto keyB64 = get_str("keyBase64");
              const auto key    = base64_decode(keyB64);

              // Probe format — only v1 blobs should arrive here.
              {
                std::ifstream probe(src, std::ios::binary);
                char magic[8] = {};
                probe.read(magic, 8);
                if (std::string(magic, 8) != "LVCRYPT1")
                  throw std::runtime_error(
                      "v0 blob sent to native bridge — use DartCryptoEngine");
              }

              decrypt_file_v1(src, dst, key);
              (*result_ptr)->Success(flutter::EncodableValue());

            } else {
              (*result_ptr)->NotImplemented();
            }
          } catch (const std::exception& e) {
            (*result_ptr)->Error("CRYPTO_ERROR", e.what(), nullptr);
          }
        }).detach();
      });
}
