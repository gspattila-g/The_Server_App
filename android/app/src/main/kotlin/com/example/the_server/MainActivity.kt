package com.example.the_server

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val channel = NotificationChannel(
            "high_importance_channel",
            "Chat üzenetek",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Értesítések új chat üzenetekről"
            enableVibration(true)
        }
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(channel)
    }
}
