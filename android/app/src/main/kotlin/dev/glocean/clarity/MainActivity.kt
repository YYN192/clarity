package dev.glocean.clarity

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createSevereWeatherChannel()
    }

    /**
     * Creates the channel FCM messages are routed to (see the
     * default_notification_channel_id meta-data in AndroidManifest).
     *
     * Without it, alerts land in Android's generic "Miscellaneous" channel and
     * the user cannot control severe-weather notifications separately from
     * anything else the app might send. Creating an existing channel is a
     * no-op, so this is safe on every launch — but note the channel's
     * importance and sound are user-owned after first creation and cannot be
     * changed by the app.
     */
    private fun createSevereWeatherChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            getString(R.string.severe_weather_channel_id),
            getString(R.string.severe_weather_channel_name),
            // HIGH so alerts surface as a heads-up notification: these are
            // time-critical safety warnings, not ambient updates.
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.severe_weather_channel_description)
            enableVibration(true)
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }
}
