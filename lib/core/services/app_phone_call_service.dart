import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/follow_ups/data/model/follow_up_models.dart';
import '../../ui/leads/data/model/lead_models.dart';
import '../../ui/leads/presentation/widgets/lead_call_sheets.dart';
import '../utils/url_dialer_helper.dart';

/// Telephony & Dialer Service for ACADENO CRM (FR-3.1 - FR-3.5).
///
/// Features:
/// 1. Native system dialer launch with target lead phone number on Android and Web.
/// 2. Requests call log permissions (`READ_CALL_LOG`) on Android.
/// 3. Detects when executive finishes call and returns to the app (`AppLifecycleState.resumed`).
/// 4. Captures exact talk-time call duration in minutes/seconds from Android CallLog.
/// 5. Automatically prompts the Call Outcome sheet with the real duration pre-filled.
class AppPhoneCallService with WidgetsBindingObserver {
  AppPhoneCallService._();
  static final AppPhoneCallService instance = AppPhoneCallService._();

  static const MethodChannel _channel = MethodChannel(
    'com.acadeno.crm/phone_call',
  );

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

  /// Launches the system phone dialer pad for [item] and starts duration tracking.
  Future<void> dialFollowUpItem(
    BuildContext context,
    ExecutiveFollowUpItem item,
  ) async {
    final lead = ExecutiveLeadItem(
      id: item.id,
      name: item.leadName,
      initials: item.leadName.isNotEmpty ? item.leadName[0].toUpperCase() : 'L',
      maskedPhone: item.maskedPhone,
      fullPhone: item.phone.isNotEmpty ? item.phone : item.maskedPhone,
      collegeInfo: item.collegeInfo,
      statusTag: 'Follow-up',
      statusColor: const Color(0xFFEF8144),
      statusBg: const Color(0xFFFEF0E6),
      campaignTag: item.note,
      followUpTime: item.timeLabel,
    );
    await dialLead(context, lead);
  }

  /// Launches the system phone dialer pad for [lead] and starts duration tracking.
  Future<void> dialLead(BuildContext context, ExecutiveLeadItem lead) async {
    _activeLead = lead;
    _activeContext = context;
    _dialStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    _isWaitingForCallReturn = true;

    final rawPhone = lead.fullPhone.isNotEmpty
        ? lead.fullPhone
        : lead.maskedPhone;
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (cleanPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid phone number for this lead.')),
        );
      }
      return;
    }

    if (kIsWeb) {
      // 1. Web browser: Trigger system dialer pad via tel: URI
      await UrlDialerHelper.openDialer(cleanPhone);
      return;
    }

    if (Platform.isAndroid) {
      try {
        // 2. Android: Immediately launch system phone dialer pad
        await _channel.invokeMethod('launchDialer', {'phone': cleanPhone});
        return;
      } catch (e) {
        debugPrint('[AppPhoneCallService] Native dialer notice: $e');
      }
    }

    // 3. Fallback for iOS or desktop platforms
    await UrlDialerHelper.openDialer(cleanPhone);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _isWaitingForCallReturn &&
        _activeLead != null) {
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

    final cleanPhone =
        (lead.fullPhone.isNotEmpty ? lead.fullPhone : lead.maskedPhone)
            .replaceAll(RegExp(r'[^0-9+]'), '');

    int durationSeconds = 0;
    bool permissionDenied = false;
    bool foundCallLog = false;

    // Retry querying Android CallLog up to 4 times (with 700ms intervals)
    // because Android Telecom writes the CallLog entry asynchronously upon hangup
    for (int attempt = 0; attempt < 4; attempt++) {
      await Future.delayed(Duration(milliseconds: attempt == 0 ? 800 : 700));
      if (!context.mounted) return;

      if (!kIsWeb && Platform.isAndroid) {
        try {
          final res = await _channel.invokeMethod<int>('getLastCallDuration', {
            'phone': cleanPhone,
            'startTimestamp': startMs,
          });

          if (res != null && res >= 0) {
            // EXACT talk-time duration from the Android telephony CallLog!
            durationSeconds = res;
            foundCallLog = true;
            break;
          } else if (res == -1) {
            permissionDenied = true;
            break;
          }
        } catch (_) {
          break;
        }
      }
    }

    // Only open the Call Outcome update alert box if the person was actually called!
    // If the executive only navigated to the dialer pad and returned without calling, skip dialog.
    if (!kIsWeb && Platform.isAndroid) {
      if (!permissionDenied && !foundCallLog) {
        debugPrint(
          '[AppPhoneCallService] No outgoing call to $cleanPhone detected in CallLog. Skipping outcome dialog.',
        );
        return;
      }

      if (permissionDenied) {
        final elapsedMs = DateTime.now().millisecondsSinceEpoch - startMs;
        if (elapsedMs < 7000) {
          debugPrint(
            '[AppPhoneCallService] User returned immediately (<7s) without call. Skipping outcome dialog.',
          );
          return;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tip: Allow Call Log permission to automatically read call duration.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - startMs;
      if (elapsedMs < 7000) {
        debugPrint(
          '[AppPhoneCallService] User returned immediately (<7s). Skipping outcome dialog.',
        );
        return;
      }
    }

    // Format duration: e.g. "2m 18s" or "45s" or "0s"
    final formattedDuration = _formatDuration(durationSeconds);

    // Automatically open Call Outcome sheet only when call was made
    if (context.mounted) {
      LeadCallSheets.showCallAndOutcomeSheet(
        context,
        leadId: lead.id,
        leadName: lead.name,
        maskedPhone: lead.maskedPhone,
        collegeInfo: lead.collegeInfo,
        campaignTag: lead.campaignTag,
        initialDuration: formattedDuration,
        course: lead.course,
        fee: lead.fee,
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
