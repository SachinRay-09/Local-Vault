package com.yourname.local_vault

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
  private val CHANNEL = "local_vault/file_opener"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "openFile" -> {
          val path = call.argument<String>("path")
          if (path.isNullOrBlank()) {
            result.error("ARGUMENT_ERROR", "Missing 'path'", null)
            return@setMethodCallHandler
          }

          try {
            val file = File(path)
            val uri: Uri = FileProvider.getUriForFile(
              this,
              applicationContext.packageName + ".fileprovider",
              file
            )

            val intent = Intent(Intent.ACTION_VIEW).apply {
              setDataAndType(uri, contentResolver.getType(uri) ?: "*/*")
              addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
              addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            startActivity(intent)
            result.success(null)
          } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
          }
        }
        else -> result.notImplemented()
      }
    }
  }
}
