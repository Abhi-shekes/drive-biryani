package com.drivebiryani.drivebiryani

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * Runs for the few seconds a Google sign-in is in flight.
 *
 * Linking an account uses a loopback OAuth redirect: the app listens on
 * 127.0.0.1 and Google redirects the browser there with the authorization
 * code. But launching the browser puts this app in the background, where
 * Android's cached-app freezer suspends the process — the socket stays open
 * at the kernel level while nothing is ever scheduled to accept it, so the
 * browser just times out. A foreground service keeps the process running
 * long enough to receive the redirect, and is stopped the moment the flow
 * ends either way.
 */
class SignInKeepAliveService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        return START_NOT_STICKY
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Signing in",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown only while a Google account is being linked."
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("Finishing Google sign-in")
            .setContentText("Waiting for Google to send you back to DriveBiryani.")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "signin_keepalive"
        private const val NOTIFICATION_ID = 4711
    }
}
