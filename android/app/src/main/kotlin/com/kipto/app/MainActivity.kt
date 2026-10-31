package com.kipto.app

import android.Manifest
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.provider.Telephony
import android.service.notification.NotificationListenerService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    /** Lets the app read bank SMS to suggest expenses; see lib/sms/sms_source.dart. */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kipto/sms")
        liveChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasSmsPermission())
                "requestPermission" -> requestSmsPermission(result)
                "ensureLivePermission" -> {
                    // Granted without a prompt once READ_SMS is: same permission group.
                    if (hasSmsPermission() && !isGranted(Manifest.permission.RECEIVE_SMS)) {
                        requestPermissions(arrayOf(Manifest.permission.RECEIVE_SMS), LIVE_PERMISSION_REQUEST)
                    }
                    // Some phones unbind listeners they've stopped; ask for it back.
                    if (hasNotificationAccess()) NotificationListenerService.requestRebind(messageListener())
                    result.success(null)
                }
                "hasNotificationAccess" -> result.success(hasNotificationAccess())
                "openNotificationAccessSettings" -> {
                    openNotificationAccessSettings()
                    result.success(null)
                }
                "inbox" -> readInbox(call.argument<Number>("since")?.toLong() ?: 0L, result)
                "openAppSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)),
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        liveChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun isGranted(permission: String) = checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun hasSmsPermission() = isGranted(Manifest.permission.READ_SMS)

    private fun messageListener() = ComponentName(this, MessageNotificationListener::class.java)

    /** Whether [MessageNotificationListener] may read notifications, for RCS messages. */
    private fun hasNotificationAccess(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            return getSystemService(NotificationManager::class.java).isNotificationListenerAccessGranted(messageListener())
        }
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return messageListener().flattenToString() in enabled.split(':')
    }

    /** Kipto's own switch where the phone has one, else the list of apps. */
    private fun openNotificationAccessSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                startActivity(
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                        .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, messageListener().flattenToString()),
                )
                return
            } catch (e: ActivityNotFoundException) {
                // Falls through to the list.
            }
        }
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (hasSmsPermission()) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(
            arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
            SMS_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQUEST) {
            // READ_SMS decides: it's what reading the inbox needs.
            pendingPermission?.success(hasSmsPermission())
            pendingPermission = null
        }
    }

    /** Inbox messages after [since] (ms since epoch), newest first, read off the main thread. */
    private fun readInbox(since: Long, result: MethodChannel.Result) {
        if (!hasSmsPermission()) {
            result.error("permission", "READ_SMS is not granted", null)
            return
        }
        Thread {
            try {
                val messages = mutableListOf<Map<String, Any>>()
                contentResolver.query(
                    Telephony.Sms.Inbox.CONTENT_URI,
                    arrayOf(Telephony.Sms._ID, Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
                    "${Telephony.Sms.DATE} > ?",
                    arrayOf(since.toString()),
                    "${Telephony.Sms.DATE} DESC",
                )?.use { cursor ->
                    while (cursor.moveToNext()) {
                        messages.add(
                            mapOf(
                                "id" to cursor.getLong(0).toString(),
                                "address" to (cursor.getString(1) ?: ""),
                                "body" to (cursor.getString(2) ?: ""),
                                "date" to cursor.getLong(3),
                            ),
                        )
                    }
                }
                runOnUiThread { result.success(messages) }
            } catch (e: Exception) {
                runOnUiThread { result.error("read_failed", e.message, null) }
            }
        }.start()
    }

    companion object {
        private const val SMS_PERMISSION_REQUEST = 4217
        private const val LIVE_PERMISSION_REQUEST = 4218

        /**
         * The running app's SMS channel, while it has one; MessageHandoff gives
         * new messages to it rather than starting Flutter in the background.
         */
        @Volatile
        var liveChannel: MethodChannel? = null
    }
}
