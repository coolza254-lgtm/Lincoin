package io.github.coolza254.lincoin

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the "lincoin/installer" channel used by the in-app update buttons:
 * reads an APK's version and installs it over the running app through a
 * PackageInstaller session (see [SelfUpdater]). Android verifies that the
 * signature matches the installed app.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lincoin/installer")
        channel = ch
        SelfUpdater.listener = { status, message ->
            runOnUiThread {
                channel?.invokeMethod(
                    "installStatus",
                    mapOf("status" to status, "message" to message)
                )
            }
        }
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "apkInfo" -> result.success(apkInfo(call.argument<String>("path")!!))
                    "canInstall" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                    )
                    "openInstallPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                )
                            )
                        }
                        result.success(null)
                    }
                    "install" -> {
                        val file = File(call.argument<String>("path")!!)
                        // Copying the APK into the session takes a moment; keep it off the UI thread.
                        Thread {
                            try {
                                SelfUpdater.install(applicationContext, file)
                                runOnUiThread { result.success(null) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("installer", e.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("installer", e.message, null)
            }
        }
    }

    override fun onDestroy() {
        SelfUpdater.listener = null
        channel = null
        super.onDestroy()
    }

    private fun apkInfo(path: String): Map<String, Any?>? {
        val info: PackageInfo = (
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageArchiveInfo(path, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageArchiveInfo(path, 0)
            }
        ) ?: return null
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return mapOf(
            "packageName" to info.packageName,
            "versionCode" to code,
            "versionName" to info.versionName
        )
    }
}
