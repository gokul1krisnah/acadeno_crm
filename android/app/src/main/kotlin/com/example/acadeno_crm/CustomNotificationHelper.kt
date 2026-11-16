package com.example.acadeno_crm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat

object CustomNotificationHelper {
    // Unique updated channel ID to ensure fresh configuration across all Android devices
    const val CHANNEL_ID = "acadeno_crm_notifications_v3"
    const val CHANNEL_NAME = "Leads & Tasks"

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High priority notifications for assigned leads, follow-ups, and tasks"
                enableLights(true)
                lightColor = Color.parseColor("#EA580C")
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 200, 250)
                setShowBadge(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    fun showCustomNotification(
        context: Context,
        title: String,
        body: String,
        payload: String? = null,
        id: Int = 1001,
        subText: String? = null
    ) {
        createNotificationChannel(context)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("payload", payload ?: "")
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(context, id, intent, flags)

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        // Modern District-style right-side emblem (high-contrast, user-friendly badge)
        val largeIcon = try {
            val raw = BitmapFactory.decodeResource(context.resources, R.drawable.ic_notification_large)
            if (raw != null) {
                getDistrictStyleEmblem(raw)
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }

        val actionIntent = PendingIntent.getActivity(context, id + 10, intent, flags)

        // Calculate clean single header subtext (e.g. "Leads", "Follow-ups", "Visits")
        // This explicitly prevents Android from duplicating the App Name in the notification header!
        val resolvedSubText = if (!subText.isNullOrBlank()) {
            subText
        } else if (title.contains("Lead", ignoreCase = true) || body.contains("Lead", ignoreCase = true)) {
            "Leads"
        } else if (title.contains("Visit", ignoreCase = true)) {
            "Visits"
        } else if (title.contains("Follow", ignoreCase = true)) {
            "Follow-ups"
        } else {
            "Updates"
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setSubText(resolvedSubText)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle(title)
                    .bigText(body)
                    .setSummaryText(resolvedSubText)
            )
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setSound(soundUri)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setColor(Color.parseColor("#EA580C"))
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(R.drawable.ic_notification, "Check tasks", actionIntent)

        if (largeIcon != null) {
            builder.setLargeIcon(largeIcon)
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(id, builder.build())
    }

    private fun getDistrictStyleEmblem(src: Bitmap): Bitmap {
        val size = minOf(src.width, src.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        val shader = BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        paint.shader = shader
        val rect = RectF(0f, 0f, size.toFloat(), size.toFloat())
        val radius = size * 0.22f
        canvas.drawRoundRect(rect, radius, radius, paint)
        return output
    }
}
