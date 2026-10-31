package com.kipto.app

import android.content.Context
import android.os.Handler
import android.os.Looper

/**
 * Gives a message that might be a bank's to the app: straight to it if it's
 * running, otherwise through [SmsBackground]. Whether it's a spend is
 * decided in Dart (lib/sms/sms_parser.dart), the same as for the inbox.
 */
object MessageHandoff {
    /** Banks send from letter codes like VM-HDFCBK or names; people from numbers. */
    fun mightBeBank(sender: String) = sender.any { it.isLetter() }

    fun deliver(context: Context, sender: String, body: String, date: Long, done: () -> Unit) {
        val message = mapOf<String, Any>("address" to sender, "body" to body, "date" to date)
        Handler(Looper.getMainLooper()).post {
            val live = MainActivity.liveChannel
            if (live != null) {
                live.invokeMethod("received", message)
                done()
            } else {
                SmsBackground.handle(context.applicationContext, message, done)
            }
        }
    }
}
