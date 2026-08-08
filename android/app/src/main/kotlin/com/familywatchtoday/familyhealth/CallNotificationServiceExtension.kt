package com.familywatchtoday.familyhealth

import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.app.NotificationCompat
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension
import java.net.URL

/**
 * Intercepts the backend's `type: incoming_call` push (see CallRingNotifier)
 * before OneSignal's default display, so we can post our own full-screen-
 * intent notification instead — the only way to reliably auto-launch a
 * ringing UI (over the lock screen, no tap needed) when the app is
 * backgrounded or fully killed. Registered via the
 * com.onesignal.NotificationServiceExtension meta-data in AndroidManifest.xml.
 *
 * Skips entirely while the app is actually in the foreground — in that case
 * OneSignal's normal pipeline runs instead, which Dart's
 * addForegroundWillDisplayListener already hooks to show IncomingCallScreen
 * immediately (no notification detour needed).
 */
class CallNotificationServiceExtension : INotificationServiceExtension {

    companion object {
        private const val CHANNEL_ID = "incoming_call_channel"
    }

    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val data = event.notification.additionalData ?: return
        if (data.optString("type") != "incoming_call") return

        val context = event.context
        if (isAppInForeground(context)) return

        event.preventDefault()
        val callerName = data.optString("caller_name", "Unknown")
        val callerAvatarUrl = data.optString("caller_avatar_url", null)
        val callInvitationId = data.optInt("call_invitation_id", 0)
        val notificationId = event.notification.androidNotificationId

        createChannel(context)

        val fullScreenIntent = Intent(context, IncomingCallActivity::class.java).apply {
            putExtra(IncomingCallActivity.EXTRA_CALLER_NAME, callerName)
            putExtra(IncomingCallActivity.EXTRA_CALLER_AVATAR_URL, callerAvatarUrl)
            putExtra(IncomingCallActivity.EXTRA_CALL_INVITATION_ID, callInvitationId)
            putExtra(IncomingCallActivity.EXTRA_NOTIFICATION_ID, notificationId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            context, notificationId, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Accept must be an Activity PendingIntent, not a broadcast — Android
        // blocks starting an Activity from a plain background BroadcastReceiver,
        // so a broadcast-based Accept silently does nothing. Routing straight to
        // IncomingCallActivity with auto-accept skips the ring UI entirely and
        // jumps directly into the video call.
        val acceptIntent = Intent(context, IncomingCallActivity::class.java).apply {
            putExtra(IncomingCallActivity.EXTRA_CALLER_NAME, callerName)
            putExtra(IncomingCallActivity.EXTRA_CALL_INVITATION_ID, callInvitationId)
            putExtra(IncomingCallActivity.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(IncomingCallActivity.EXTRA_AUTO_ACCEPT, true)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val acceptPendingIntent = PendingIntent.getActivity(
            context, notificationId * 10 + 1, acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Decline needs no UI, so a broadcast is fine here.
        val declineIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = CallActionReceiver.ACTION_DECLINE
            putExtra(CallActionReceiver.EXTRA_CALL_INVITATION_ID, callInvitationId)
            putExtra(CallActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
        }
        val declinePendingIntent = PendingIntent.getBroadcast(
            context, notificationId * 10 + 2, declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Plain text actions — this OEM's heads-up peek doesn't render custom
        // RemoteViews layouts, but it does render standard notification
        // actions, so that's what actually shows up reliably.
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setContentTitle("Incoming video call")
            .setContentText("$callerName is calling…")
            .setOngoing(true)
            .setAutoCancel(true)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(0, "Decline", declinePendingIntent)
            .addAction(0, "Accept", acceptPendingIntent)

        fetchAvatarBitmap(callerAvatarUrl)?.let { builder.setLargeIcon(it) }

        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(notificationId, builder.build())
    }

    private fun fetchAvatarBitmap(url: String?): Bitmap? {
        if (url.isNullOrEmpty()) return null
        return try {
            URL(url).openStream().use { BitmapFactory.decodeStream(it) }
        } catch (e: Exception) {
            null
        }
    }

    private fun isAppInForeground(context: Context): Boolean {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return false
        val processes = am.runningAppProcesses ?: return false
        return processes.any {
            it.processName == context.packageName &&
                it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        }
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(CHANNEL_ID, "Incoming Calls", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Incoming video call alerts"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }
}
