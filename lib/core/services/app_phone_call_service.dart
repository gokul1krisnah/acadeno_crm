import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/follow_ups/data/model/follow_up_models.dart';
import '../../ui/leads/data/model/lead_models.dart';
import '../../ui/leads/data/sources/leads_rds.dart';
import '../utils/url_dialer_helper.dart';

/// Telephony & Dialer Service for ACADENO CRM.
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
  bool _hasLeftApp = false;

  /// Attaches global navigator key (retained for API compatibility).
  void attachNavigatorKey(GlobalKey<NavigatorState> key) {}

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
    final rawPhone = lead.fullPhone.isNotEmpty
        ? lead.fullPhone
        : lead.maskedPhone;
    final cleanPhone = LeadPhoneValidator.formatDialablePhone(rawPhone);

    if (cleanPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid phone number for this lead.')),
        );
      }
      return;
    }

    // Atomically claim 10-minute Call Lock before launching dialer
    if (lead.id.isNotEmpty) {
      final lockResult = await LeadsRds().claimLeadForCall(lead.id);
      if (!lockResult.granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${lockResult.lockedBy ?? "Another executive"} is calling now (10-min lock active).',
              ),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
        return;
      }
    }

    _activeLead = lead;
    _dialStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    _isWaitingForCallReturn = true;
    _hasLeftApp = false;

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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_isWaitingForCallReturn) {
        _hasLeftApp = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isWaitingForCallReturn && _activeLead != null) {
        final elapsed =
            DateTime.now().millisecondsSinceEpoch - _dialStartTimeMs;
        // If app hasn't actually left/paused yet and elapsed < 1200ms, ignore transient resume
        if (!_hasLeftApp && elapsed < 1200) {
          debugPrint(
            '[AppPhoneCallService] Ignoring transient resume before app left ($elapsed ms)',
          );
          return;
        }
        _isWaitingForCallReturn = false;
        _hasLeftApp = false;
        _handleCallReturn();
      }
    }
  }

  Future<void> _handleCallReturn() async {
    final lead = _activeLead;
    final startMs = _dialStartTimeMs;
    _activeLead = null;

    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startMs;
    // Debounce accidental same-frame re-entry (< 150ms)
    if (elapsedMs < 150) return;

    if (lead == null) return;

    // Release active call lock on return without automatically opening any popup.
    if (lead.id.isNotEmpty) {
      unawaited(LeadsRds().releaseLeadLock(lead.id));
    }
  }

  void dispose() {
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
      _initialized = false;
    }
  }
}
