package www.azizul.com

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val INSTALLER_CHANNEL = "www.azizul.com/app_installer"
    private val SOCIAL_SHARE_CHANNEL = "www.azizul.com/social_share"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        requestNotificationPermission()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "Berkas APK tidak ditemukan di: $filePath", null)
                            return@setMethodCallHandler
                        }
                        val apkUri: Uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.localizedMessage, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "File path tidak boleh kosong", null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOCIAL_SHARE_CHANNEL).setMethodCallHandler { call, result ->
            val filePath = call.argument<String>("filePath")
            if (filePath == null) {
                result.error("INVALID_ARGS", "File path tidak boleh kosong", null)
                return@setMethodCallHandler
            }
            val file = File(filePath)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "Berkas gambar tidak ditemukan: $filePath", null)
                return@setMethodCallHandler
            }
            val imageUri: Uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )

            when (call.method) {
                "shareToInstagram" -> {
                    val caption = call.argument<String>("caption") ?: ""
                    try {
                        val storyIntent = Intent("com.instagram.share.ADD_TO_STORY").apply {
                            setDataAndType(imageUri, "image/png")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            putExtra("interactive_asset_uri", imageUri)
                            setPackage("com.instagram.android")
                        }
                        if (packageManager.resolveActivity(storyIntent, 0) != null) {
                            startActivity(storyIntent)
                            result.success(true)
                            return@setMethodCallHandler
                        }

                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "image/png"
                            putExtra(Intent.EXTRA_STREAM, imageUri)
                            if (caption.isNotEmpty()) {
                                putExtra(Intent.EXTRA_TEXT, caption)
                            }
                            setPackage("com.instagram.android")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(sendIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTAGRAM_ERROR", e.localizedMessage, null)
                    }
                }
                "shareToWhatsApp" -> {
                    val text = call.argument<String>("text") ?: ""
                    try {
                        val packages = arrayOf("com.whatsapp", "com.whatsapp.w4b")
                        var launched = false
                        for (pkg in packages) {
                            try {
                                val waIntent = Intent(Intent.ACTION_SEND).apply {
                                    type = "image/png"
                                    putExtra(Intent.EXTRA_STREAM, imageUri)
                                    if (text.isNotEmpty()) {
                                        putExtra(Intent.EXTRA_TEXT, text)
                                    }
                                    setPackage(pkg)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(waIntent)
                                launched = true
                                break
                            } catch (_: Exception) {
                                // Try next package
                            }
                        }
                        if (launched) {
                            result.success(true)
                        } else {
                            result.error("WHATSAPP_NOT_INSTALLED", "Aplikasi WhatsApp tidak terpasang di perangkat ini.", null)
                        }
                    } catch (e: Exception) {
                        result.error("WHATSAPP_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "high_importance_channel"
            val channelName = "Notifikasi E-Learning"
            val channelDescription = "Saluran notifikasi untuk materi belajar, tugas, kuis, dan pengumuman sekolah"
            val importance = NotificationManager.IMPORTANCE_HIGH

            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableLights(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 250, 250)
                setSound(soundUri, audioAttributes)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.createNotificationChannel(channel)
        }
    }
}
