package io.github.coolza254.lincoin

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import java.io.File

/**
 * Installs a new version of Lincoin over itself with a PackageInstaller
 * session, so the update happens inside the app (no file manager, no
 * separate "open APK" step).
 *
 * On Android 12+ the session asks not to require confirmation. Android
 * allows that only in some cases (e.g. once Lincoin is the installer of
 * record of itself); otherwise it asks the user once, via
 * STATUS_PENDING_USER_ACTION, and we show the system dialog.
 */
object SelfUpdater {
    const val ACTION_RESULT = "io.github.coolza254.lincoin.INSTALL_RESULT"

    /** Reports (status, message) to the Flutter side while the app is open. */
    @Volatile
    var listener: ((String, String?) -> Unit)? = null

    fun install(context: Context, apk: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(context.packageName)
        params.setSize(apk.length())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        val sessionId = installer.createSession(params)
        try {
            installer.openSession(sessionId).use { session ->
                apk.inputStream().use { input ->
                    session.openWrite("base.apk", 0, apk.length()).use { out ->
                        input.copyTo(out)
                        session.fsync(out)
                    }
                }
                val intent = Intent(context, InstallResultReceiver::class.java).setAction(ACTION_RESULT)
                var flags = PendingIntent.FLAG_UPDATE_CURRENT
                // The installer adds the result as extras, so the intent must be mutable.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
                val pending = PendingIntent.getBroadcast(context, sessionId, intent, flags)
                session.commit(pending.intentSender)
            }
        } catch (e: Exception) {
            installer.abandonSession(sessionId)
            throw e
        }
    }
}

/** Receives the session result from the system installer. */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                if (confirm != null) {
                    confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirm)
                }
                SelfUpdater.listener?.invoke("confirm", null)
            }
            PackageInstaller.STATUS_SUCCESS -> SelfUpdater.listener?.invoke("success", null)
            PackageInstaller.STATUS_FAILURE_ABORTED -> SelfUpdater.listener?.invoke("aborted", message)
            PackageInstaller.STATUS_FAILURE_CONFLICT,
            PackageInstaller.STATUS_FAILURE_INCOMPATIBLE -> SelfUpdater.listener?.invoke("conflict", message)
            PackageInstaller.STATUS_FAILURE_STORAGE -> SelfUpdater.listener?.invoke("storage", message)
            else -> SelfUpdater.listener?.invoke("failed", message)
        }
    }
}

/**
 * After Lincoin replaced itself, try to open it again. Android may block
 * starting an activity from the background; then the user opens it from
 * the launcher as usual.
 */
class UpdatedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        try {
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(it)
            }
        } catch (e: Exception) {
            // Background start blocked: the user reopens the app themselves.
        }
    }
}
