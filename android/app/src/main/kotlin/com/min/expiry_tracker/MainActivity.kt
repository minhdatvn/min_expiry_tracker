package com.min.expiry_tracker

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.min.expiry_tracker/incoming_file"
    }

    private var methodChannel: MethodChannel? = null
    private var pendingFilePath: String? = null
    private var isFlutterReady: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            handleIncomingIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialFile") {
                isFlutterReady = true
                val filePath = pendingFilePath
                pendingFilePath = null
                result.success(filePath)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent == null) return
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> extractStreamUri(intent)
            else -> null
        }

        if (uri == null) return

        // Chép luồng dữ liệu ra file tạm ở luồng nền để không làm khựng giao diện
        Thread {
            val cachedPath = copyUriToCache(uri)
            if (cachedPath != null) {
                runOnUiThread {
                    if (isFlutterReady && methodChannel != null) {
                        methodChannel?.invokeMethod("onFileReceived", cachedPath)
                    } else {
                        pendingFilePath = cachedPath
                    }
                }
            }
        }.start()
    }

    @Suppress("DEPRECATION")
    private fun extractStreamUri(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val tempFile = File(
                cacheDir,
                "incoming_${System.currentTimeMillis()}.minexpiry"
            )
            contentResolver.openInputStream(uri)?.use { input ->
                tempFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            } ?: return null

            if (tempFile.length() > 0) tempFile.absolutePath else null
        } catch (_: Exception) {
            null
        }
    }
}