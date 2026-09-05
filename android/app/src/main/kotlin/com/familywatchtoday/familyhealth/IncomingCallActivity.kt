package com.familywatchtoday.familyhealth

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import android.widget.ImageView
import android.widget.TextView
import java.net.URL

/**
 * Native full-screen ringing UI — shown via a full-screen notification intent
 * (see CallNotificationServiceExtension) so it appears automatically even
 * when the app is backgrounded or fully killed, which the Dart-level
 * OneSignal listeners can't do on their own (they only run while the Flutter
 * engine is alive).
 */
class IncomingCallActivity : Activity() {

    companion object {
        const val EXTRA_CALLER_NAME = "caller_name"
        const val EXTRA_CALLER_AVATAR_URL = "caller_avatar_url"
        const val EXTRA_CALL_INVITATION_ID = "call_invitation_id"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        /** Set when launched from the notification's Accept button — skips the
         *  ring UI entirely and jumps straight into the video call. */
        const val EXTRA_AUTO_ACCEPT = "auto_accept"
        private const val TAG = "IncomingCallActivity"
    }

    private var ringtone: android.media.Ringtone? = null
    private var callerName = "Unknown"
    private var callInvitationId = 0
    private var notificationId = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        callerName = intent.getStringExtra(EXTRA_CALLER_NAME) ?: "Unknown"
        callInvitationId = intent.getIntExtra(EXTRA_CALL_INVITATION_ID, 0)
        notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(notificationId)

        if (intent.getBooleanExtra(EXTRA_AUTO_ACCEPT, false)) {
            performAccept()
            return
        }

        val callerAvatarUrl = intent.getStringExtra(EXTRA_CALLER_AVATAR_URL)
        setContentView(R.layout.activity_incoming_call)
        findViewById<TextView>(R.id.caller_name).text = callerName
        loadAvatar(callerAvatarUrl)
        playRingtone()

        findViewById<android.widget.Button>(R.id.accept_button).setOnClickListener { performAccept() }
        findViewById<android.widget.Button>(R.id.decline_button).setOnClickListener { performDecline() }
    }

    private fun performAccept() {
        stopRingtone()
        CallInvitationApi.respond(this, callInvitationId, "accepted")
        val launch = Intent(this, MainActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_OPEN_VIDEO_CALL, true)
            putExtra(MainActivity.EXTRA_CALLER_NAME, callerName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(launch)
        finish()
    }

    private fun performDecline() {
        stopRingtone()
        CallInvitationApi.respond(this, callInvitationId, "declined")
        finish()
    }

    private fun loadAvatar(url: String?) {
        if (url.isNullOrEmpty()) return
        Thread {
            try {
                URL(url).openStream().use { stream ->
                    val bitmap = BitmapFactory.decodeStream(stream)
                    if (bitmap != null) {
                        runOnUiThread {
                            findViewById<ImageView>(R.id.caller_avatar).setImageBitmap(bitmap)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "avatar load failed: ${e.message}")
            }
        }.start()
    }

    private fun playRingtone() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(this, uri)
            ringtone?.play()
        } catch (e: Exception) {
            Log.w(TAG, "ringtone failed: ${e.message}")
        }
    }

    private fun stopRingtone() {
        ringtone?.takeIf { it.isPlaying }?.stop()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopRingtone()
    }
}
