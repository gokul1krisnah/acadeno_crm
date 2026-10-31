import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/leads/data/model/lead_models.dart';
import '../../ui/leads/presentation/widgets/lead_call_sheets.dart';

/// Telephony & Dialer Service for ACADENO CRM (FR-3.1 - FR-3.5).
///
/// Features:
/// 1. Native system dialer launch with target lead phone number.
/// 2. Requests call log permissions (`READ_CALL_LOG`) on Android.
/// 3. Detects when executive finishes call and returns to the app (`AppLifecycleState.resumed`).
/// 4. Captures exact call duration in minutes/seconds from Android CallLog (or elapsed time fallback).
/// 5. Automatically prompts the Call Outcome sheet with the real duration pre-filled.
class AppPhoneCallService with WidgetsBindingObserver {
  AppPhoneCallService._();
  static final AppPhoneCallService instance = AppPhoneCallService._();

  static const MethodChannel _channel = MethodChannel('com.acadeno.crm/phone_call');

  bool _initialized = false;
  ExecutiveLeadItem? _activeLead;
  int _dialStartTimeMs = 0;
  bool _isWaitingForCallReturn = false;
  BuildContext? _activeContext;

  /// Initializes lifecycle observation for automatic post-call return detection.
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    requestPermissions();
  }

  /// Requests Android runtime permissions for Call Log duration tracking.
  Future<void> requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestPermissions');
    } catch (_) {}
  }

  /// Launches the system phone dialer pad for [lead] and starts duration tracking.
  Future<void> dialLead(BuildContext context, ExecutiveLeadItem lead) async {
    _activeLead = lead;
    _activeContext = context;
    _dialStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    _isWaitingForCallReturn = true;

    final rawPhone = lead.fullPhone.isNotEmpty ? lead.fullPhone : lead.maskedPhone;
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid phone number for this lead.')),
      );
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('launchDialer', {'phone': cleanPhone});
        return;
      } catch (e) {
        debugPrint('[AppPhoneCallService] Native dialer notice: $e');
      }
    }

    // Direct fallback if native channel unavailable or on non-Android platform
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dialing ${lead.name} ($cleanPhone)... Return to app after call.'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isWaitingForCallReturn && _activeLead != null) {
      _isWaitingForCallReturn = false;
      _handleCallReturn();
    }
  }

  Future<void> _handleCallReturn() async {
    final lead = _activeLead;
    final context = _activeContext;
    final startMs = _dialStartTimeMs;
    _activeLead = null;

    if (lead == null || context == null || !context.mounted) return;

    // Small delay so Android OS completes writing call record to CallLog
    await Future.delayed(const Duration(milliseconds: 650));
    if (!context.mounted) return;

    int durationSeconds = 0;

    // 1. Try querying native Android CallLog for the exact recorded call duration
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final cleanPhone = lead.fullPhone.replaceAll(RegExp(r'[^0-9+]'), '');
        final nativeDuration = await _channel.invokeMethod<int>('getLastCallDuration', {
          'phone': cleanPhone,
          'startTimestamp': startMs,
        });
        if (nativeDuration != null && nativeDuration > 0) {
          durationSeconds = nativeDuration;
        }
      } catch (e) {
        debugPrint('[AppPhoneCallService] CallLog query notice: $e');
      }
    }

    // 2. Fallback to wall-clock elapsed time if CallLog wasn't accessible
    if (durationSeconds <= 0 && startMs > 0) {
      final elapsed = (DateTime.now().millisecondsSinceEpoch - startMs) ~/ 1000;
      // If elapsed is under 5 seconds, it was likely canceled or misdialed
      durationSeconds = elapsed > 0 ? elapsed : 0;
    }

    // Format duration: e.g. "2m 18s" or "45s"
    final formattedDuration = _formatDuration(durationSeconds);

    // 3. Automatically open Call Outcome sheet with the exact duration pre-filled
    if (context.mounted) {
      LeadCallSheets.showCallAndOutcomeSheet(
        context,
        leadId: lead.id,
        leadName: lead.name,
        maskedPhone: lead.maskedPhone,
        collegeInfo: lead.collegeInfo,
        campaignTag: lead.campaignTag,
        initialDuration: formattedDuration,
      );
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0) {
      return '${mins}m ${secs.toString().padLeft(2, '0')}s';
    }
    return '${secs}s';
  }

  void dispose() {
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
      _initialized = false;
    }
  }
}
