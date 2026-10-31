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
                        val uri = Uri.parse("tel:" + Uri.encode(phone))
                        val intent = Intent(Intent.ACTION_DIAL, uri).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("DIALER_ERROR", e.localizedMessage, null)
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

                var inspectedCount = 0
                while (it.moveToNext() && inspectedCount < 25) {
                    inspectedCount++
                    val number = if (numberIdx != -1) it.getString(numberIdx) ?: "" else ""
                    val cleanNumber = number.replace(Regex("[^0-9]"), "")
                    val numberLast10 = if (cleanNumber.length >= 10) cleanNumber.takeLast(10) else cleanNumber
                    val callDate = if (dateIdx != -1) it.getLong(dateIdx) else 0L

                    // Call must be recent: either within 2 minutes before dial button tapped or within last 15 minutes
                    val isRecent = if (afterTimestamp > 0) {
                        callDate >= (afterTimestamp - 120000L)
                    } else {
                        System.currentTimeMillis() - callDate <= 900000L
                    }

                    val isNumberMatch = targetLast10.isNotEmpty() && (
                        numberLast10 == targetLast10 ||
                        cleanNumber.endsWith(targetLast10) ||
                        cleanTarget.endsWith(numberLast10)
                    )

                    if (isNumberMatch && isRecent) {
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
