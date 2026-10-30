package com.kipto.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Runs `smsReceivedInBackground` in lib/main.dart for one SMS, in a Flutter
 * engine of its own, then shuts it down. Used when the app isn't running.
 */
object SmsBackground {
    private const val TAG = "KiptoSms"

    /** Generous, but well inside the time Android allows a receiver. */
    private const val TIMEOUT_MS = 20_000L

    fun handle(context: Context, message: Map<String, Any>, done: () -> Unit) {
        val main = Handler(Looper.getMainLooper())
        main.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(context)
                loader.ensureInitializationCompleteAsync(context, null, main) {
                    run(context, loader.findAppBundlePath(), message, main, done)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Could not start Flutter for an SMS", e)
                done()
            }
        }
    }

    private fun run(
        context: Context,
        bundlePath: String,
        message: Map<String, Any>,
        main: Handler,
        done: () -> Unit,
    ) {
        val engine = FlutterEngine(context)
        var finished = false
        val finish = Runnable {
            if (!finished) {
                finished = true
                engine.destroy()
                done()
            }
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "kipto/sms_background").setMethodCallHandler { call, result ->
            when (call.method) {
                // Dart is up and asks for the SMS.
                "ready" -> result.success(message)
                "done" -> {
                    result.success(null)
                    main.post(finish)
                }
                else -> result.notImplemented()
            }
        }
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(bundlePath, "smsReceivedInBackground"),
        )
        main.postDelayed(finish, TIMEOUT_MS)
    }
}
