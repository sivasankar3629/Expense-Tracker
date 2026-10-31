package com.kipto.app

import android.app.Notification
import android.app.Person
import android.os.Build
import android.os.Bundle
import android.os.Parcelable
import android.provider.Telephony
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Reads new messages from the messaging app's notifications, once the user
 * allows notification access. Banks and shops increasingly send RCS chats,
 * which apps can't read and which never reach [SmsReceiver]; their
 * notifications are the only way to see them. Only messaging apps are
 * looked at; everything else is ignored.
 */
class MessageNotificationListener : NotificationListenerService() {
    /** Notifications are re-posted as a conversation updates: hand each message over once. */
    private val recent = ArrayDeque<String>()

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in messagingApps()) return
        val notification = sbn.notification ?: return
        if ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
        val (sender, body, date) = latestMessage(notification, sbn.postTime) ?: return
        if (body.isBlank() || !MessageHandoff.mightBeBank(sender)) return

        val key = "$sender\n$body"
        if (key in recent) return
        recent.addLast(key)
        if (recent.size > RECENT_LIMIT) recent.removeFirst()

        MessageHandoff.deliver(this, sender, body, date) {}
    }

    private fun messagingApps() = setOfNotNull(Telephony.Sms.getDefaultSmsPackage(this)) + KNOWN_MESSAGING_APPS

    /** The newest message someone else sent, as (sender, text, time). */
    private fun latestMessage(notification: Notification, postTime: Long): Triple<String, String, Long>? {
        val extras = notification.extras
        @Suppress("DEPRECATION")
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        if (!messages.isNullOrEmpty()) {
            val last = messages.last() as? Bundle ?: return null
            // No sender means the user sent it.
            val sender = senderOf(last) ?: return null
            val text = last.getCharSequence("text")?.toString() ?: return null
            val time = last.getLong("time").takeIf { it > 0 } ?: postTime
            return Triple(sender, text, time)
        }
        val sender = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: return null
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: return null
        return Triple(sender, text, postTime)
    }

    private fun senderOf(message: Bundle): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            @Suppress("DEPRECATION")
            val person = message.getParcelable<Parcelable>("sender_person") as? Person
            person?.name?.toString()?.let { return it }
        }
        return message.getCharSequence("sender")?.toString()
    }

    companion object {
        private const val RECENT_LIMIT = 32

        /** RCS-capable apps, in case one isn't the default SMS app. */
        private val KNOWN_MESSAGING_APPS = setOf(
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
        )
    }
}
