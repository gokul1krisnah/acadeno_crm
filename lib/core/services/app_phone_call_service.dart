import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/follow_ups/data/model/follow_up_models.dart';
import '../../ui/leads/data/model/lead_models.dart';
import '../../ui/leads/data/sources/leads_rds.dart';
import '../../ui/leads/presentation/widgets/lead_call_sheets.dart';
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
  BuildContext? _activeContext;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Attaches global navigator key for immediate fallback dialog display.
  void attachNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

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
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (cleanPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid phone number for this lead.')),
        );
      }
      return;
    }

    // FR-3.1 & RL-2: Atomically claim 10-minute Call Lock before launching dialer
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
    _activeContext = context;
    _dialStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    _isWaitingForCallReturn = true;

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
    _activeContext = null;

    final targetContext = (context != null && context.mounted)
        ? context
        : _navigatorKey?.currentContext;

    if (lead == null || targetContext == null || !targetContext.mounted) return;

    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startMs;
    // Debounce accidental same-frame re-entry (< 150ms)
    if (elapsedMs < 150) return;

    final cleanPhone =
        (lead.fullPhone.isNotEmpty ? lead.fullPhone : lead.maskedPhone)
            .replaceAll(RegExp(r'[^0-9+]'), '');

    int durationSeconds = 0;

    // Fast check on Android Telecom CallLog with quick retry (FR-3.2)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        int? res = await _channel.invokeMethod<int>('getLastCallDuration', {
          'phone': cleanPhone,
          'startTimestamp': startMs,
        }).timeout(const Duration(milliseconds: 300), onTimeout: () => null);

        // If -1 (no call found yet), give a 350ms window for the system dialer
        // process to flush the call record to the SQLite CallLog provider
        if (res == -1) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          res = await _channel.invokeMethod<int>('getLastCallDuration', {
            'phone': cleanPhone,
            'startTimestamp': startMs,
          }).timeout(const Duration(milliseconds: 350), onTimeout: () => -1);
        }

        if (res != null && res >= 0) {
          durationSeconds = res;
        }
      } catch (e) {
        debugPrint('[AppPhoneCallService] CallLog check error: $e');
      }
    }

    // FR-3.2 & FR-3.3: Always open the mandatory Call Outcome sheet on return to foreground.
    // Duration is pre-filled from CallLog when Android permits, or editable manually.
    final formattedDuration = _formatDuration(durationSeconds);

    // Immediately open Call Outcome sheet with zero delay
    if (targetContext.mounted) {
      LeadCallSheets.showCallAndOutcomeSheet(
        targetContext,
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
