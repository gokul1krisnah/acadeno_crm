package com.example.acadeno_crm

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.CallLog
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val securityChannel = "com.acadeno.crm/security"
    private val phoneCallChannel = "com.acadeno.crm/phone_call"
    private val PERMISSION_REQUEST_CODE = 4421

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Hardware-level protection: Blocks screenshots, screen recordings, and task switcher previews
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
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
                    val buildTags = android.os.Build.TAGS
                    val isTestKeys = buildTags != null && buildTags.contains("test-keys")
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
                    val isRooted = isTestKeys || suPaths.any { java.io.File(it).exists() }
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
                "requestPermissions" -> {
                    val permissions = arrayOf(
                        Manifest.permission.READ_CALL_LOG,
                        Manifest.permission.READ_PHONE_STATE
                    )
                    val needsRequest = permissions.any {
                        ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
                    }
                    if (needsRequest) {
                        ActivityCompat.requestPermissions(this, permissions, PERMISSION_REQUEST_CODE)
                    }
                    result.success(true)
                }
                "launchDialer" -> {
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
                    val startTimestamp = call.argument<Long>("startTimestamp") ?: 0L
                    val durationSeconds = queryLastCallDuration(phone, startTimestamp)
                    result.success(durationSeconds)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun queryLastCallDuration(targetPhone: String, afterTimestamp: Long): Long {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
            return -1L // Return -1 if permission not granted
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
}
