package com.kipto.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Hears every incoming SMS. Bank-looking ones go to the app: straight to it
 * if it's running, otherwise through [SmsBackground]. Whether it's a spend
 * is decided in Dart (lib/sms/sms_parser.dart), the same as for the inbox.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (parts.isNullOrEmpty()) return
        val sender = parts[0].displayOriginatingAddress ?: return
        // Banks send from letter codes like VM-HDFCBK; people from numbers.
        if (sender.none { it.isLetter() }) return
        // Long SMS arrive in parts.
        val body = parts.joinToString("") { it.displayMessageBody ?: "" }
        val message = mapOf<String, Any>(
            "address" to sender,
            "body" to body,
            "date" to System.currentTimeMillis(),
        )

        val live = MainActivity.liveChannel
        if (live != null) {
            live.invokeMethod("received", message)
            return
        }
        val pending = goAsync()
        SmsBackground.handle(context.applicationContext, message) { pending.finish() }
    }
}
