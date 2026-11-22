package com.codewingz.delivtrack

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.codewingz.delivtrack/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sharePdfToWhatsApp" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName") ?: "Invoice.pdf"
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""

                    if (bytes == null) {
                        result.error("INVALID_ARGS", "PDF bytes required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val shareDir = File(cacheDir, "share")
                        if (!shareDir.exists()) shareDir.mkdirs()
                        val file = File(shareDir, fileName)
                        FileOutputStream(file).use { it.write(bytes) }

                        val contentUri: Uri = FileProvider.getUriForFile(
                            this,
                            "${packageName}.flutter.printing",
                            file
                        )

                        val targetPackage = getInstalledWhatsAppPackage()

                        var digits = phone.filter { it.isDigit() }
                        if (digits.startsWith("03") && digits.length == 11) {
                            digits = "92" + digits.substring(1)
                        } else if (digits.startsWith("0092")) {
                            digits = digits.substring(2)
                        }

                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "application/pdf"
                            putExtra(Intent.EXTRA_STREAM, contentUri)
                            if (message.isNotEmpty()) {
                                putExtra(Intent.EXTRA_TEXT, message)
                            }
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                            if (targetPackage != null) {
                                setPackage(targetPackage)
                                if (digits.isNotEmpty()) {
                                    putExtra("jid", "$digits@s.whatsapp.net")
                                }
                            }
                        }

                        if (targetPackage != null) {
                            startActivity(intent)
                        } else {
                            val chooser = Intent.createChooser(intent, "Share Invoice")
                            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(chooser)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_FAILED", e.message, null)
                    }
                }
                "openWhatsAppChat" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    try {
                        var digits = phone.filter { it.isDigit() }
                        if (digits.startsWith("03") && digits.length == 11) {
                            digits = "92" + digits.substring(1)
                        } else if (digits.startsWith("0092")) {
                            digits = digits.substring(2)
                        }

                        val targetPackage = getInstalledWhatsAppPackage()
                        val encodedMsg = Uri.encode(message)
                        val uri = Uri.parse("whatsapp://send?phone=$digits&text=$encodedMsg")

                        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            if (targetPackage != null) {
                                setPackage(targetPackage)
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getInstalledWhatsAppPackage(): String? {
        val pm = packageManager
        return when {
            isPackageInstalled(pm, "com.whatsapp") -> "com.whatsapp"
            isPackageInstalled(pm, "com.whatsapp.w4b") -> "com.whatsapp.w4b"
            else -> null
        }
    }

    private fun isPackageInstalled(pm: android.content.pm.PackageManager, packageName: String): Boolean {
        return try {
            pm.getPackageInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }
    }
}

