package com.yourname.local_vault

import android.os.Handler
import android.os.Looper
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import java.util.concurrent.Executors

/**
 * Native AES-256-GCM crypto bridge for LVCRYPT1 v1 blobs.
 * MethodChannel: local_vault/crypto_native
 *   encryptFile(sourcePath, destPath, keyBase64) → Map{byteSize}
 *   decryptFile(sourcePath, destPath, keyBase64)  → void
 *
 * v0 blobs are never routed here — the Dart layer detects v0 and uses
 * DartCryptoEngine (AES-256-CTR) instead.
 */
class CryptoBridge(private val messenger: BinaryMessenger) {

    companion object {
        const val CHANNEL_NAME = "local_vault/crypto_native"
        private const val CHUNK_SIZE       = 524288   // 512 KB
        private const val GCM_TAG_BITS     = 128
        private const val GCM_TAG_BYTES    = 16
        private const val HEADER_RAW_BYTES = 60
        private const val HEADER_TOTAL     = 76      // 60 + 16
        private val MAGIC = "LVCRYPT1".toByteArray(Charsets.US_ASCII)
    }

    private val channel     = MethodChannel(messenger, CHANNEL_NAME)
    private val executor    = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // ─── I/O helper ───────────────────────────────────────────────────────────
    // InputStream.read(ByteArray) is not guaranteed to fill the buffer.
    // This helper retries until exactly [len] bytes are read or EOF/error occurs.
    private fun readFully(stream: InputStream, buf: ByteArray, len: Int): Int {
        var offset = 0
        while (offset < len) {
            val n = stream.read(buf, offset, len - offset)
            if (n == -1) break
            offset += n
        }
        return offset
    }

    init {
        channel.setMethodCallHandler { call, result -> handleCall(call, result) }
    }

    fun destroy() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    // ─── Dispatch ────────────────────────────────────────────────────────────

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        executor.submit {
            try {
                when (call.method) {
                    "encryptFile" -> {
                        val src    = call.argument<String>("sourcePath")!!
                        val dst    = call.argument<String>("destPath")!!
                        val keyB64 = call.argument<String>("keyBase64")!!
                        val key    = Base64.decode(keyB64, Base64.DEFAULT)
                        val size   = encryptFileV1(src, dst, key)
                        mainHandler.post { result.success(mapOf("byteSize" to size)) }
                    }
                    "decryptFile" -> {
                        val src    = call.argument<String>("sourcePath")!!
                        val dst    = call.argument<String>("destPath")!!
                        val keyB64 = call.argument<String>("keyBase64")!!
                        val key    = Base64.decode(keyB64, Base64.DEFAULT)
                        // Dart side already confirmed this is a v1 blob.
                        decryptFileV1(src, dst, key)
                        mainHandler.post { result.success(null) }
                    }
                    else -> mainHandler.post { result.notImplemented() }
                }
            } catch (e: Exception) {
                mainHandler.post { result.error("CRYPTO_ERROR", e.message, null) }
            }
        }
    }

    // ─── Nonce construction ───────────────────────────────────────────────────
    // base_nonce is 12 bytes; bytes [8..11] are overwritten with uint32_be(chunkIndex).
    // Bytes [0..7] remain random — 64-bit random prefix per file.

    private fun buildChunkNonce(baseNonce: ByteArray, index: Int): ByteArray {
        val nonce = baseNonce.copyOf(12)
        nonce[8]  = ((index ushr 24) and 0xFF).toByte()
        nonce[9]  = ((index ushr 16) and 0xFF).toByte()
        nonce[10] = ((index ushr  8) and 0xFF).toByte()
        nonce[11] = ( index          and 0xFF).toByte()
        return nonce
    }

    // ─── Header construction ──────────────────────────────────────────────────

    private fun buildHeader(originalSize: Long, fileId: ByteArray,
                             baseNonce: ByteArray): ByteArray {
        val buf = ByteBuffer.allocate(HEADER_RAW_BYTES).order(ByteOrder.BIG_ENDIAN)
        buf.put(MAGIC)              // [0..7]   magic
        buf.putShort(1)             // [8..9]   format_version = 1
        buf.putShort(1)             // [10..11] algorithm_id = 1 (AES-256-GCM)
        buf.putInt(CHUNK_SIZE)      // [12..15] chunk_size
        buf.putLong(originalSize)   // [16..23] original_size
        buf.put(fileId)             // [24..39] file_id (16 bytes)
        buf.put(baseNonce)          // [40..51] base_nonce (12 bytes)
        buf.put(ByteArray(8))       // [52..59] reserved (zeroed)
        return buf.array()
    }

    // ─── Header auth tag ──────────────────────────────────────────────────────
    // GCM over empty plaintext with AAD = header bytes → tag only.

    private fun computeHeaderTag(key: ByteArray, baseNonce: ByteArray,
                                  header: ByteArray): ByteArray {
        val nonce0 = buildChunkNonce(baseNonce, 0)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"),
                    GCMParameterSpec(GCM_TAG_BITS, nonce0))
        cipher.updateAAD(header)
        // doFinal on empty input → 16-byte tag only (javax.crypto appends tag)
        return cipher.doFinal()
    }

    // ─── v1 Encrypt ──────────────────────────────────────────────────────────

    private fun encryptFileV1(srcPath: String, dstPath: String,
                               key: ByteArray): Long {
        val srcFile      = File(srcPath)
        val originalSize = srcFile.length()
        val fileId       = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val baseNonce    = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val header       = buildHeader(originalSize, fileId, baseNonce)
        val headerTag    = computeHeaderTag(key, baseNonce, header)

        FileOutputStream(dstPath).use { fos ->
            fos.write(header)     // 60 bytes
            fos.write(headerTag)  // 16 bytes

            FileInputStream(srcFile).use { fis ->
                val plainBuf = ByteArray(CHUNK_SIZE)
                var chunkIdx = 0

                while (true) {
                    val bytesRead = readFully(fis, plainBuf, CHUNK_SIZE)
                    if (bytesRead == 0) break

                    val nonce  = buildChunkNonce(baseNonce, chunkIdx)
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    cipher.init(Cipher.ENCRYPT_MODE,
                                SecretKeySpec(key, "AES"),
                                GCMParameterSpec(GCM_TAG_BITS, nonce))
                    // doFinal returns ciphertext (bytesRead bytes) + 16-byte tag appended
                    val encrypted = cipher.doFinal(plainBuf, 0, bytesRead)
                    fos.write(encrypted)
                    chunkIdx++
                }
            }
        }
        return originalSize
    }

    // ─── v1 Decrypt ──────────────────────────────────────────────────────────

    private fun decryptFileV1(srcPath: String, dstPath: String, key: ByteArray) {
        FileInputStream(srcPath).use { fis ->
            // Read 60-byte header
            val headerBuf = ByteArray(HEADER_RAW_BYTES)
            val hRead = readFully(fis, headerBuf, HEADER_RAW_BYTES)
            require(hRead == HEADER_RAW_BYTES) { "Truncated header (got $hRead bytes)" }

            // Validate magic
            val magic = headerBuf.copyOfRange(0, 8)
            require(magic.contentEquals(MAGIC)) { "Invalid magic bytes" }

            // Read 16-byte header auth tag
            val headerTag = ByteArray(GCM_TAG_BYTES)
            val tRead = readFully(fis, headerTag, GCM_TAG_BYTES)
            require(tRead == GCM_TAG_BYTES) { "Truncated header auth tag" }

            // Parse header fields
            val bb = ByteBuffer.wrap(headerBuf).order(ByteOrder.BIG_ENDIAN)
            bb.position(12)
            val chunkSize    = bb.int           // offset 12, uint32
            val originalSize = bb.long          // offset 16, uint64 (read as Long)
            val baseNonce    = headerBuf.copyOfRange(40, 52)

            // Verify header auth tag
            val nonce0 = buildChunkNonce(baseNonce, 0)
            try {
                val verCipher = Cipher.getInstance("AES/GCM/NoPadding")
                verCipher.init(Cipher.DECRYPT_MODE,
                               SecretKeySpec(key, "AES"),
                               GCMParameterSpec(GCM_TAG_BITS, nonce0))
                verCipher.updateAAD(headerBuf)
                // headerTag is the 16-byte tag; empty ciphertext + tag → doFinal
                verCipher.doFinal(headerTag)
            } catch (e: Exception) {
                throw SecurityException("Header authentication failed: ${e.message}")
            }

            // Decrypt data chunks
            FileOutputStream(dstPath).use { fos ->
                val inBuf = ByteArray(chunkSize + GCM_TAG_BYTES)
                var chunkIdx = 0
                var totalDecrypted = 0L

                while (true) {
                    val bytesRead = readFully(fis, inBuf, chunkSize + GCM_TAG_BYTES)
                    if (bytesRead <= 0) break

                    require(bytesRead > GCM_TAG_BYTES) {
                        "Truncated chunk $chunkIdx (only $bytesRead bytes)"
                    }

                    val nonce  = buildChunkNonce(baseNonce, chunkIdx)
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    cipher.init(Cipher.DECRYPT_MODE,
                                SecretKeySpec(key, "AES"),
                                GCMParameterSpec(GCM_TAG_BITS, nonce))
                    try {
                        val plain = cipher.doFinal(inBuf, 0, bytesRead)
                        fos.write(plain)
                        totalDecrypted += plain.size
                    } catch (e: Exception) {
                        throw SecurityException(
                            "Chunk $chunkIdx auth tag mismatch: ${e.message}")
                    }
                    chunkIdx++
                }

                // Sanity check
                if (totalDecrypted != originalSize) {
                    throw IllegalStateException(
                        "Decrypted size mismatch: got $totalDecrypted, expected $originalSize")
                }
            }
        }
    }
}
