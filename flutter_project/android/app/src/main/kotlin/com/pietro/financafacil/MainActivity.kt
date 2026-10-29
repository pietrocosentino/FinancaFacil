package com.pietro.financafacil

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import java.io.FileNotFoundException
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Abre o Google Drive ou o Google Fotos diretamente para escolher um arquivo,
 * e envia arquivos ao Drive pelo "Salvar no Drive". Usa apenas os aplicativos
 * instalados no aparelho: não há login próprio nem acesso à conta Google.
 */
class MainActivity : FlutterFragmentActivity() {
    private var pendingPick: MethodChannel.Result? = null
    private var pickLimit = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isInstalled" -> result.success(
                        isInstalled(call.argument<String>("package") ?: ""),
                    )
                    "pickFromApp" -> pickFromApp(
                        call.argument<String>("package") ?: "",
                        call.argument<List<String>>("mimeTypes") ?: listOf("*/*"),
                        call.argument<Number>("maxBytes")?.toLong() ?: 0L,
                        result,
                    )
                    "pickFromDocuments" -> pickFromDocuments(
                        call.argument<List<String>>("mimeTypes") ?: listOf("*/*"),
                        call.argument<Number>("maxBytes")?.toLong() ?: 0L,
                        result,
                    )
                    "sendToApp" -> sendToApp(
                        call.argument<String>("package") ?: "",
                        call.argument<String>("name") ?: "arquivo",
                        call.argument<ByteArray>("bytes"),
                        call.argument<String>("mimeType") ?: "application/octet-stream",
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun isInstalled(packageName: String): Boolean = try {
        packageManager.getPackageInfo(packageName, 0)
        true
    } catch (_: Exception) {
        false
    }

    private fun pickFromApp(
        packageName: String,
        mimeTypes: List<String>,
        maxBytes: Long,
        result: MethodChannel.Result,
    ) {
        if (pendingPick != null) {
            result.error("BUSY", "Já existe uma escolha de arquivo aberta.", null)
            return
        }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = if (mimeTypes.size == 1) mimeTypes.first() else "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false)
            addCategory(Intent.CATEGORY_OPENABLE)
            setPackage(packageName)
        }
        try {
            pendingPick = result
            pickLimit = maxBytes
            startActivityForResult(intent, REQUEST_PICK)
        } catch (_: ActivityNotFoundException) {
            pendingPick = null
            result.error("APP_NOT_FOUND", "Aplicativo não encontrado.", null)
        }
    }

    private fun pickFromDocuments(
        mimeTypes: List<String>,
        maxBytes: Long,
        result: MethodChannel.Result,
    ) {
        if (pendingPick != null) {
            result.error("BUSY", "Já existe uma escolha de arquivo aberta.", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            type = if (mimeTypes.size == 1) mimeTypes.first() else "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false)
            addCategory(Intent.CATEGORY_OPENABLE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            pendingPick = result
            pickLimit = maxBytes
            startActivityForResult(intent, REQUEST_PICK)
        } catch (_: ActivityNotFoundException) {
            pendingPick = null
            result.error(
                "APP_NOT_FOUND",
                "Nenhum seletor de arquivos está disponível.",
                null,
            )
        }
    }

    @Deprecated("Fluxo de resultado da FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PICK) return
        val result = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        val limit = pickLimit
        Thread {
            try {
                val file = mapOf("name" to displayName(uri), "bytes" to readLimited(uri, limit))
                runOnUiThread { result.success(file) }
            } catch (error: TooLargeException) {
                runOnUiThread { result.error("TOO_LARGE", "Arquivo acima do limite.", null) }
            } catch (error: Exception) {
                runOnUiThread { result.error("READ_FAILED", error.message, null) }
            }
        }.start()
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val name = cursor.getString(0)
                    if (!name.isNullOrBlank()) return name
                }
            }
        return uri.lastPathSegment ?: "arquivo"
    }

    private fun readLimited(uri: Uri, maxBytes: Long): ByteArray {
        val typed = try {
            contentResolver.openTypedAssetFileDescriptor(
                uri,
                XLSX_MIME_TYPE,
                null,
            )
        } catch (_: FileNotFoundException) {
            null
        }
        if (typed != null) {
            return typed.use { descriptor ->
                readLimited(descriptor.createInputStream(), maxBytes)
            }
        }
        val input = contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Não foi possível abrir o arquivo.")
        return readLimited(input, maxBytes)
    }

    private fun readLimited(input: java.io.InputStream, maxBytes: Long): ByteArray {
        input.use { stream ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            var total = 0L
            while (true) {
                val read = stream.read(buffer)
                if (read < 0) break
                total += read
                if (maxBytes > 0 && total > maxBytes) throw TooLargeException()
                output.write(buffer, 0, read)
            }
            return output.toByteArray()
        }
    }

    private fun sendToApp(
        packageName: String,
        name: String,
        bytes: ByteArray?,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        if (bytes == null || bytes.isEmpty()) {
            result.error("EMPTY", "Arquivo vazio.", null)
            return
        }
        try {
            val folder = File(cacheDir, "exports").apply { mkdirs() }
            folder.listFiles()?.forEach { it.delete() }
            val safeName = name.replace(Regex("[^A-Za-z0-9._ -]"), "_").ifBlank { "arquivo" }
            val file = File(folder, safeName).apply { writeBytes(bytes) }
            val uri = FileProvider.getUriForFile(this, "${applicationContext.packageName}.files", file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TITLE, safeName)
                clipData = ClipData.newRawUri(safeName, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                setPackage(packageName)
            }
            startActivity(intent)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.error("APP_NOT_FOUND", "Aplicativo não encontrado.", null)
        } catch (error: Exception) {
            result.error("SEND_FAILED", error.message, null)
        }
    }

    private class TooLargeException : Exception()

    companion object {
        private const val CHANNEL = "financafacil/cloud_files"
        private const val REQUEST_PICK = 7301
        private const val XLSX_MIME_TYPE =
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    }
}
