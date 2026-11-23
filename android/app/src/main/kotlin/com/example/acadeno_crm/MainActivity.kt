package com.example.acadeno_crm

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.CallLog
import android.provider.ContactsContract
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val securityChannel = "com.acadeno.crm/security"
    private val phoneCallChannel = "com.acadeno.crm/phone_call"
    private val notificationChannel = "com.acadeno.crm/notifications"
    private val PERMISSION_REQUEST_CODE = 4421
    private val CONTACTS_PERMISSION_REQUEST_CODE = 4422
    private var pendingCallLogPermResult: MethodChannel.Result? = null
    private var pendingContactsPermResult: MethodChannel.Result? = null
    private var didPlaceCall = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Block screenshots and screen recording by default (FLAG_SECURE)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        try {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            tm?.listen(object : PhoneStateListener() {
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    super.onCallStateChanged(state, phoneNumber)
                    if (state == TelephonyManager.CALL_STATE_OFFHOOK) {
                        didPlaceCall = true
                    }
                }
            }, PhoneStateListener.LISTEN_CALL_STATE)
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Screen Security Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecure" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                "disableSecure" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                "isSecureEnabled" -> {
                    val isSecure = (window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0
                    result.success(isSecure)
                }
                "getDeviceInfo" -> {
                    try {
                        val androidId = android.provider.Settings.Secure.getString(
                            contentResolver,
                            android.provider.Settings.Secure.ANDROID_ID
                        ) ?: "unknown_android"
                        val manufacturer = android.os.Build.MANUFACTURER.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
                        val model = android.os.Build.MODEL
                        val deviceName = "$manufacturer $model"
                        result.success(mapOf("deviceId" to androidId, "deviceName" to deviceName))
                    } catch (e: Exception) {
                        result.success(mapOf("deviceId" to "android_${System.currentTimeMillis()}", "deviceName" to "Android Device"))
                    }
                }
                "checkDeviceIntegrity" -> {
                    val suPaths = arrayOf(
                        "/system/app/Superuser.apk",
                        "/sbin/su",
                        "/system/bin/su",
                        "/system/xbin/su",
                        "/data/local/xbin/su",
                        "/data/local/bin/su",
                        "/system/sd/xbin/su",
                        "/system/bin/failsafe/su",
                        "/data/local/su"
                    )
                    // Check actual su binaries; do not flag test-keys in debug builds
                    val isRooted = suPaths.any { java.io.File(it).exists() }
                    val isEmulator = android.os.Build.FINGERPRINT.startsWith("generic") ||
                                     android.os.Build.MODEL.contains("google_sdk") ||
                                     android.os.Build.MODEL.contains("Emulator")
                    result.success(mapOf("isRooted" to isRooted, "isEmulator" to isEmulator))
                }
                else -> result.notImplemented()
            }
        }

        // 2. Native Phone Call & Call Log Duration Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, phoneCallChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "checkContactsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestPermissions" -> {
                    val permissions = arrayOf(
                        Manifest.permission.READ_CALL_LOG,
                        Manifest.permission.READ_CONTACTS,
                        Manifest.permission.READ_PHONE_STATE
                    )
                    val needsRequest = permissions.any {
                        ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
                    }
                    if (needsRequest) {
                        pendingCallLogPermResult?.success(
                            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
                        )
                        pendingCallLogPermResult = result
                        ActivityCompat.requestPermissions(this, permissions, PERMISSION_REQUEST_CODE)
                    } else {
                        result.success(true)
                    }
                }
                "requestContactsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
                    if (granted) {
                        result.success(true)
                    } else {
                        pendingContactsPermResult?.success(false)
                        pendingContactsPermResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_CONTACTS),
                            CONTACTS_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "launchDialer" -> {
                    didPlaceCall = false
                    val phone = call.argument<String>("phone") ?: ""
                    try {
                        val cleanPhone = phone.trim()
                        val uri = Uri.fromParts("tel", cleanPhone, null)
                        val intent = Intent(Intent.ACTION_DIAL, uri).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val cleanPhone = phone.trim()
                            val fallbackUri = Uri.parse("tel:$cleanPhone")
                            val intent = Intent(Intent.ACTION_VIEW, fallbackUri).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("DIALER_ERROR", e2.localizedMessage, null)
                        }
                    }
                }
                "getLastCallDuration" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val startTimestamp = (call.argument<Number>("startTimestamp"))?.toLong() ?: 0L
                    val durationSeconds = queryLastCallDuration(phone, startTimestamp)
                    if (durationSeconds == -2L) {
                        // Permission not granted: use hardware TelephonyManager state
                        if (!didPlaceCall) {
                            result.success(-1L)
                        } else {
                            result.success(0L)
                        }
                    } else if (durationSeconds == -1L && !didPlaceCall) {
                        result.success(-1L)
                    } else if (durationSeconds >= 0L) {
                        result.success(durationSeconds)
                    } else {
                        result.success(-1L)
                    }
                }
                "getCallLogs" -> {
                    val limit = (call.argument<Number>("limit"))?.toInt() ?: 100
                    val logs = queryDeviceCallLogs(limit)
                    result.success(logs)
                }
                else -> result.notImplemented()
            }
        }

        // 3. Custom Figma System Notification Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "showCustomNotification" -> {
                    val title = call.argument<String>("title") ?: "Reminder"
                    val body = call.argument<String>("body") ?: ""
                    val payload = call.argument<String>("payload")
                    val id = (call.argument<Number>("id"))?.toInt() ?: 1001
                    val subText = call.argument<String>("subText")
                    try {
                        CustomNotificationHelper.showCustomNotification(
                            context = applicationContext,
                            title = title,
                            body = body,
                            payload = payload,
                            id = id,
                            subText = subText
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NOTIFICATION_ERROR", e.localizedMessage, null)
                    }
                }
                "scheduleRepeatingLeadReminder" -> {
                    val requestCode = (call.argument<Number>("requestCode"))?.toInt() ?: 3001
                    val intervalHours = (call.argument<Number>("intervalHours"))?.toLong() ?: 12L
                    val title = call.argument<String>("title") ?: "Lead Reminder"
                    val body = call.argument<String>("body") ?: ""
                    val subText = call.argument<String>("subText") ?: "Leads"
                    val payload = call.argument<String>("payload") ?: ""
                    try {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val intent = Intent(applicationContext, LeadReminderReceiver::class.java).apply {
                            putExtra("title", title)
                            putExtra("body", body)
                            putExtra("subText", subText)
                            putExtra("payload", payload)
                            putExtra("id", requestCode)
                        }
                        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        val pendingIntent = PendingIntent.getBroadcast(
                            applicationContext,
                            requestCode,
                            intent,
                            flags
                        )
                        val intervalMillis = intervalHours * 60L * 60L * 1000L
                        val firstTriggerAt = System.currentTimeMillis() + intervalMillis
                        alarmManager.setInexactRepeating(
                            AlarmManager.RTC_WAKEUP,
                            firstTriggerAt,
                            intervalMillis,
                            pendingIntent
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SCHEDULE_ERROR", e.localizedMessage, null)
                    }
                }
                "cancelLeadReminder" -> {
                    val requestCode = (call.argument<Number>("requestCode"))?.toInt() ?: 3001
                    try {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val intent = Intent(applicationContext, LeadReminderReceiver::class.java)
                        val flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                        val pendingIntent = PendingIntent.getBroadcast(
                            applicationContext,
                            requestCode,
                            intent,
                            flags
                        )
                        if (pendingIntent != null) {
                            alarmManager.cancel(pendingIntent)
                            pendingIntent.cancel()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CANCEL_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun queryLastCallDuration(targetPhone: String, afterTimestamp: Long): Long {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            return -2L // Return -2 if permission not granted
        }

        try {
            val cleanTarget = targetPhone.replace(Regex("[^0-9]"), "")
            val targetLast10 = if (cleanTarget.length >= 10) cleanTarget.takeLast(10) else cleanTarget

            val projection = arrayOf(
                CallLog.Calls.NUMBER,
                CallLog.Calls.DURATION,
                CallLog.Calls.DATE,
                CallLog.Calls.TYPE
            )

            // Query the most recent 25 calls on the device, ordered by DATE descending
            val cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                projection,
                null,
                null,
                "${CallLog.Calls.DATE} DESC"
            )

            cursor?.use {
                val numberIdx = it.getColumnIndex(CallLog.Calls.NUMBER)
                val durationIdx = it.getColumnIndex(CallLog.Calls.DURATION)
                val dateIdx = it.getColumnIndex(CallLog.Calls.DATE)
                val typeIdx = it.getColumnIndex(CallLog.Calls.TYPE)

                var inspectedCount = 0
                while (it.moveToNext() && inspectedCount < 25) {
                    inspectedCount++
                    val number = if (numberIdx != -1) it.getString(numberIdx) ?: "" else ""
                    val cleanNumber = number.replace(Regex("[^0-9]"), "")
                    val numberLast10 = if (cleanNumber.length >= 10) cleanNumber.takeLast(10) else cleanNumber
                    val callDate = if (dateIdx != -1) it.getLong(dateIdx) else 0L
                    val callType = if (typeIdx != -1) it.getInt(typeIdx) else 0

                    // Only match outgoing calls placed during this dialing session
                    val isOutgoing = (callType == CallLog.Calls.OUTGOING_TYPE)
                    val isRecent = if (afterTimestamp > 0) {
                        callDate >= (afterTimestamp - 3000L)
                    } else {
                        System.currentTimeMillis() - callDate <= 900000L
                    }

                    val isNumberMatch = targetLast10.isNotEmpty() && (
                        numberLast10 == targetLast10 ||
                        cleanNumber.endsWith(targetLast10) ||
                        cleanTarget.endsWith(numberLast10)
                    )

                    if (isNumberMatch && isRecent && isOutgoing) {
                        val duration = if (durationIdx != -1) it.getLong(durationIdx) else 0L
                        // Return actual call talk time in seconds as recorded by the carrier
                        return duration
                    }
                }
            }
        } catch (e: Exception) {
            // Permission or provider exception
        }
        return -2L // Call record not yet committed
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val callLogGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_CALL_LOG
            ) == PackageManager.PERMISSION_GRANTED
            pendingCallLogPermResult?.success(callLogGranted)
            pendingCallLogPermResult = null
        } else if (requestCode == CONTACTS_PERMISSION_REQUEST_CODE) {
            val contactsGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_CONTACTS
            ) == PackageManager.PERMISSION_GRANTED
            pendingContactsPermResult?.success(contactsGranted)
            pendingContactsPermResult = null
        }
    }

    /**
     * Loads a normalized phone -> displayName map from the device's saved contacts
     * ONLY when READ_CONTACTS permission is granted.
     *
     * Matching rules:
     * - Strips spaces, dashes, parentheses, and '+' to get raw digits.
     * - For numbers with >= 10 digits, stores both the full stripped digits and the
     *   canonical last 10 digits (matching +91/0/local formatting differences safely).
     * - For 6..9 digit numbers, stores only exact stripped digits (never suffix-matched)
     *   to avoid false-positive contact names.
     */
    private fun loadSavedContactsMap(): Pair<Map<String, String>, Map<String, String>> {
        val exactMap = mutableMapOf<String, String>()
        val last10Map = mutableMapOf<String, String>()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            return Pair(exactMap, last10Map)
        }

        try {
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.NUMBER,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
            )
            val cursor = contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                null,
                null,
                null
            )
            cursor?.use {
                val numIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                while (it.moveToNext()) {
                    val rawNum = if (numIdx != -1) it.getString(numIdx) ?: "" else ""
                    val rawName = if (nameIdx != -1) it.getString(nameIdx)?.trim() ?: "" else ""
                    if (rawNum.isBlank() || rawName.isBlank()) continue

                    val digits = rawNum.replace(Regex("[^0-9]"), "")
                    if (digits.length < 6) continue

                    // Avoid storing a name that is just the phone number itself
                    val nameDigits = rawName.replace(Regex("[^0-9]"), "")
                    if (nameDigits.isNotEmpty() && nameDigits == digits) continue

                    exactMap.putIfAbsent(digits, rawName)
                    if (digits.length >= 10) {
                        val last10 = digits.takeLast(10)
                        last10Map.putIfAbsent(last10, rawName)
                    }
                }
            }
        } catch (_: Exception) {}

        return Pair(exactMap, last10Map)
    }

    private fun queryDeviceCallLogs(limit: Int): List<Map<String, Any>> {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            return emptyList()
        }

        val (exactContacts, last10Contacts) = loadSavedContactsMap()
        val logs = mutableListOf<Map<String, Any>>()
        try {
            var simName = "Mobile"
            try {
                val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                val opName = tm?.simOperatorName ?: tm?.networkOperatorName
                if (!opName.isNullOrBlank()) {
                    simName = opName
                }
            } catch (_: Exception) {}

            val projection = arrayOf(
                CallLog.Calls._ID,
                CallLog.Calls.NUMBER,
                CallLog.Calls.DATE,
                CallLog.Calls.DURATION,
                CallLog.Calls.TYPE
            )

            val cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                projection,
                null,
                null,
                "${CallLog.Calls.DATE} DESC"
            )

            cursor?.use {
                val idIdx = it.getColumnIndex(CallLog.Calls._ID)
                val numberIdx = it.getColumnIndex(CallLog.Calls.NUMBER)
                val dateIdx = it.getColumnIndex(CallLog.Calls.DATE)
                val durationIdx = it.getColumnIndex(CallLog.Calls.DURATION)
                val typeIdx = it.getColumnIndex(CallLog.Calls.TYPE)

                var count = 0
                while (it.moveToNext() && count < limit) {
                    val id = if (idIdx != -1) it.getString(idIdx) ?: count.toString() else count.toString()
                    val rawNumber = if (numberIdx != -1) it.getString(numberIdx) ?: "" else ""
                    val callDate = if (dateIdx != -1) it.getLong(dateIdx) else 0L
                    val duration = if (durationIdx != -1) it.getLong(durationIdx) else 0L
                    val callTypeInt = if (typeIdx != -1) it.getInt(typeIdx) else 0

                    val typeStr = when (callTypeInt) {
                        CallLog.Calls.INCOMING_TYPE -> "incoming"
                        CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                        CallLog.Calls.MISSED_TYPE -> "missed"
                        CallLog.Calls.VOICEMAIL_TYPE -> "voicemail"
                        CallLog.Calls.REJECTED_TYPE -> "rejected"
                        CallLog.Calls.BLOCKED_TYPE -> "blocked"
                        else -> "unknown"
                    }

                    if (rawNumber.isNotBlank()) {
                        val digits = rawNumber.replace(Regex("[^0-9]"), "")
                        val matchedName = when {
                            digits.length >= 10 -> exactContacts[digits] ?: last10Contacts[digits.takeLast(10)]
                            digits.length >= 6 -> exactContacts[digits]
                            else -> null
                        } ?: ""

                        logs.add(
                            mapOf(
                                "id" to id,
                                "number" to rawNumber,
                                "contactName" to matchedName,
                                "timestamp" to callDate,
                                "duration" to duration,
                                "type" to typeStr,
                                "simName" to simName
                            )
                        )
                        count++
                    }
                }
            }
        } catch (_: Exception) {}
        return logs
    }
}
