package com.familywatchtoday.familyhealth

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges the native incoming-call ring flow (IncomingCallActivity, launched
 * from a push) back into Dart when the user taps Accept.
 *
 * Two cases, because onNewIntent fires instead of onCreate whenever
 * MainActivity's task already exists (i.e. the Flutter engine is already
 * running — the app was merely backgrounded, not killed):
 *  - Fresh launch (onCreate, engine not up yet): stash the caller name;
 *    Dart pulls it once at splash via "getPendingCallLaunch".
 *  - Already running (onNewIntent, engine alive): push it to Dart directly
 *    via invokeMethod("openVideoCall") — splash already ran, so nothing
 *    would ever ask for a pulled value again.
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val EXTRA_OPEN_VIDEO_CALL = "open_video_call"
        const val EXTRA_CALLER_NAME = "caller_name"
        private const val CHANNEL = "com.familywatchtoday.familyhealth/call"
    }

    private var pendingCallerName: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.getBooleanExtra(EXTRA_OPEN_VIDEO_CALL, false) == true) {
            pendingCallerName = intent.getStringExtra(EXTRA_CALLER_NAME)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra(EXTRA_OPEN_VIDEO_CALL, false)) {
            val callerName = intent.getStringExtra(EXTRA_CALLER_NAME)
            if (callerName != null) {
                methodChannel?.invokeMethod("openVideoCall", mapOf("callerName" to callerName))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "getPendingCallLaunch") {
                val callerName = pendingCallerName
                pendingCallerName = null
                if (callerName != null) {
                    result.success(mapOf("callerName" to callerName))
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
        methodChannel = channel
    }
}
