package com.shadowdiary.hsyr

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.shadowdiary.hsyr/backup_export"
    private val copyExecutor = Executors.newSingleThreadExecutor()
    private var pendingSave: PendingSave? = null

    private val createDocument = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val pending = pendingSave ?: return@registerForActivityResult
        if (result.resultCode != Activity.RESULT_OK || result.data?.data == null) {
            pendingSave = null
            pending.result.success(null)
            return@registerForActivityResult
        }
        copyToUri(pending, result.data!!.data!!)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveTemporaryZip") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingSave != null) {
                    result.error("transfer_in_progress", "Another backup save is running.", null)
                    return@setMethodCallHandler
                }
                val sourcePath = call.argument<String>("sourcePath")
                val suggestedName = call.argument<String>("suggestedName")
                val source = sourcePath?.let(::validatedTemporaryFile)
                if (source == null || suggestedName.isNullOrBlank()) {
                    result.error("invalid_source", "The temporary backup is invalid.", null)
                    return@setMethodCallHandler
                }
                pendingSave = PendingSave(source, result)
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "application/zip"
                    putExtra(Intent.EXTRA_TITLE, safeFileName(suggestedName))
                }
                try {
                    createDocument.launch(intent)
                } catch (error: Throwable) {
                    pendingSave = null
                    result.error("picker_failed", error.message, null)
                }
            }
    }

    private fun validatedTemporaryFile(path: String): File? {
        return validatedFileInDirectories(path, listOf(cacheDir, codeCacheDir))
    }

    private fun copyToUri(pending: PendingSave, target: Uri) {
        copyExecutor.execute {
            try {
                contentResolver.openOutputStream(target, "w")?.use { output ->
                    FileInputStream(pending.source).use { input ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            output.write(buffer, 0, count)
                        }
                        output.flush()
                    }
                } ?: throw IOException("Unable to open destination")
                runOnUiThread {
                    if (pendingSave === pending) {
                        pendingSave = null
                        pending.result.success(target.toString())
                    }
                }
            } catch (error: Throwable) {
                runOnUiThread {
                    if (pendingSave === pending) {
                        pendingSave = null
                        pending.result.error("save_failed", error.message, null)
                    }
                }
            }
        }
    }

    private fun safeFileName(value: String): String {
        val name = value.substringAfterLast('/').substringAfterLast('\\')
        return name.replace(Regex("[^A-Za-z0-9._-]"), "_").ifBlank { "shadow-diary-backup.zip" }
    }

    override fun onDestroy() {
        val pending = pendingSave
        pendingSave = null
        pending?.result?.error("activity_destroyed", "Activity was destroyed.", null)
        copyExecutor.shutdownNow()
        super.onDestroy()
    }

    private data class PendingSave(val source: File, val result: MethodChannel.Result)
}
