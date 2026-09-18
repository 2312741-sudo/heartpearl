package com.heartpearl.heartpearl

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java) ?: return

            // 1. Chat messages channel (High importance for heads-up alert, sound & vibration)
            val messagesChannel = NotificationChannel(
                "heartpearl_messages",
                "Tin nhắn HeartPearl",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Thông báo tin nhắn mới từ bạn bè"
                enableVibration(true)
                enableLights(true)
            }

            // 2. Social notifications channel (Moments, reactions, friend requests)
            val socialChannel = NotificationChannel(
                "heartpearl_social",
                "Thông báo xã hội",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Thông báo khoảnh khắc, cảm xúc và lời mời kết bạn"
                enableVibration(true)
            }

            notificationManager.createNotificationChannel(messagesChannel)
            notificationManager.createNotificationChannel(socialChannel)
        }
    }
}
