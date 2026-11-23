package com.example.acadeno_crm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives repeating AlarmManager triggers for categorized leads:
 * - Hot Lead: every 6 hours
 * - Follow-up: every 12 hours
 * - Reminder: every 24 hours
 */
class LeadReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "Lead Reminder"
        val body = intent.getStringExtra("body") ?: "Please follow up with your lead."
        val subText = intent.getStringExtra("subText") ?: "Leads"
        val payload = intent.getStringExtra("payload")
        val notifId = intent.getIntExtra("id", 3001)

        try {
            CustomNotificationHelper.showCustomNotification(
                context = context.applicationContext,
                title = title,
                body = body,
                payload = payload,
                id = notifId,
                subText = subText,
            )
        } catch (_: Exception) {}
    }
}
