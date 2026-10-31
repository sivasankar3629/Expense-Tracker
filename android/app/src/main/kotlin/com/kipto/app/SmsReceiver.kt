package com.kipto.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Hears every incoming SMS, even when the app isn't running, and hands
 * bank-looking ones to [MessageHandoff]. RCS messages never come here; see
 * [MessageNotificationListener].
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (parts.isNullOrEmpty()) return
        val sender = parts[0].displayOriginatingAddress ?: return
        if (!MessageHandoff.mightBeBank(sender)) return
        // Long SMS arrive in parts.
        val body = parts.joinToString("") { it.displayMessageBody ?: "" }
        val pending = goAsync()
        MessageHandoff.deliver(context, sender, body, System.currentTimeMillis()) { pending.finish() }
    }
}
