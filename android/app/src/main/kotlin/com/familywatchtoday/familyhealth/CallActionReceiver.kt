package com.familywatchtoday.familyhealth

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Handles the Decline action button on the incoming-call notification (see
 * CallNotificationServiceExtension). Accept is deliberately NOT handled here
 * — Android blocks starting an Activity from a plain background
 * BroadcastReceiver, so Accept is wired as an Activity PendingIntent
 * straight to IncomingCallActivity (auto-accept) instead.
 */
class CallActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_DECLINE = "com.familywatchtoday.familyhealth.ACTION_CALL_DECLINE"
        const val EXTRA_CALL_INVITATION_ID = "call_invitation_id"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val callInvitationId = intent.getIntExtra(EXTRA_CALL_INVITATION_ID, 0)
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)

        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(notificationId)

        if (intent.action == ACTION_DECLINE) {
            CallInvitationApi.respond(context, callInvitationId, "declined")
        }
    }
}
