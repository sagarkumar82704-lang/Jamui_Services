package com.jamuiservice.provider

import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val RECEIPT_CHANNEL = "com.jamuiservice.receipt/file_actions"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECEIPT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "savePdfToDownloads" -> {
                    val fileName = call.argument<String>("fileName")?.replace(Regex("[^a-zA-Z0-9._-]"), "_")
                        ?: "JamuiServices_Receipt.pdf"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("INVALID_BYTES", "PDF byte payload cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val savedPath = savePdfToDevice(fileName, bytes)
                        result.success(mapOf("status" to "saved", "path" to savedPath))
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", e.localizedMessage ?: "Failed to save PDF", null)
                    }
                }
                "sharePdfFile" -> {
                    val fileName = call.argument<String>("fileName")?.replace(Regex("[^a-zA-Z0-9._-]"), "_")
                        ?: "JamuiServices_Receipt.pdf"
                    val bytes = call.argument<ByteArray>("bytes")
                    val subject = call.argument<String>("subject") ?: "Jamui Services Order Receipt"
                    val text = call.argument<String>("text") ?: ""
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("INVALID_BYTES", "PDF byte payload cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        sharePdfViaChooser(fileName, bytes, subject, text)
                        result.success(mapOf("status" to "shared"))
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.localizedMessage ?: "Failed to share PDF", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun savePdfToDevice(fileName: String, bytes: ByteArray): String {
        val receiptsDir = File(cacheDir, "receipts")
        if (!receiptsDir.exists()) receiptsDir.mkdirs()
        val cachedFile = File(receiptsDir, fileName)
        FileOutputStream(cachedFile).use { it.write(bytes) }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val itemUri = resolver.insert(collection, contentValues)
            if (itemUri != null) {
                resolver.openOutputStream(itemUri)?.use { out ->
                    out.write(bytes)
                }
                contentValues.clear()
                contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(itemUri, contentValues, null, null)
                return "Downloads/$fileName"
            }
        }

        val fallbackDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
        if (!fallbackDir.exists()) fallbackDir.mkdirs()
        val destFile = File(fallbackDir, fileName)
        FileOutputStream(destFile).use { it.write(bytes) }
        return destFile.absolutePath
    }

    private fun sharePdfViaChooser(fileName: String, bytes: ByteArray, subject: String, text: String) {
        val receiptsDir = File(cacheDir, "receipts")
        if (!receiptsDir.exists()) receiptsDir.mkdirs()
        val pdfFile = File(receiptsDir, fileName)
        FileOutputStream(pdfFile).use { it.write(bytes) }

        val authority = "${applicationContext.packageName}.fileprovider"
        val contentUri = FileProvider.getUriForFile(this, authority, pdfFile)

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, contentUri)
            putExtra(Intent.EXTRA_SUBJECT, subject)
            if (text.isNotBlank()) {
                putExtra(Intent.EXTRA_TEXT, text)
            }
            clipData = ClipData.newRawUri(fileName, contentUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val chooser = Intent.createChooser(shareIntent, subject).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(chooser)
    }
}
