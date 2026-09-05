package com.familywatchtoday.familyhealth

import android.content.Context
import android.util.Log
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * Native (non-Flutter) accept/decline for an incoming call, used by
 * IncomingCallActivity so the response can fire immediately even if the
 * Flutter engine isn't running yet. Reads the same auth token Dart's
 * AuthService stores via shared_preferences (flutter.auth_token in the
 * FlutterSharedPreferences file).
 */
object CallInvitationApi {
    private const val TAG = "CallInvitationApi"
    private const val BASE_URL = "https://familywatchtoday.com"

    fun respond(context: Context, callInvitationId: Int, status: String) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.auth_token", null)
        if (token == null) {
            Log.w(TAG, "No auth token stored; cannot respond to call invitation.")
            return
        }

        Thread {
            try {
                val url = URL("$BASE_URL/api/patient/call-invitations/$callInvitationId")
                val conn = url.openConnection() as HttpURLConnection
                // HttpURLConnection can't send PATCH directly (JDK restriction) —
                // Laravel/Symfony honor this override header on a POST instead.
                conn.requestMethod = "POST"
                conn.setRequestProperty("X-HTTP-Method-Override", "PATCH")
                conn.setRequestProperty("Authorization", "Bearer $token")
                conn.setRequestProperty("Accept", "application/json")
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true
                conn.connectTimeout = 15000
                conn.readTimeout = 15000

                OutputStreamWriter(conn.outputStream).use { it.write("{\"status\":\"$status\"}") }

                Log.d(TAG, "respond($status) status: ${conn.responseCode}")
                conn.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "respond error: ${e.message}")
            }
        }.start()
    }
}
