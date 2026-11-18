import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../follow_ups/data/sources/follow_ups_rds.dart';
import '../../../leads/data/model/lead_models.dart';
import '../../../leads/data/sources/leads_rds.dart';
import '../model/call_log_model.dart';

class CallLogsRds {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  static const MethodChannel _channel = MethodChannel(
    'com.acadeno.crm/phone_call',
  );

  CallLogsRds({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _callCategorizations =>
      _firestore.collection('call_categorizations');

  CollectionReference<Map<String, dynamic>> get _leads =>
      _firestore.collection('leads');

  CollectionReference<Map<String, dynamic>> get _leadPhones =>
      _firestore.collection('lead_phones');

  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  String get currentUserDisplayName {
    final user = _firebaseAuth.currentUser;
    final name = user?.displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = user?.email?.trim() ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return 'Executive';
  }

  /// Whether current platform supports native carrier call logs (Android only).
  bool get isPlatformSupported => !kIsWeb && Platform.isAndroid;

  /// Checks if Android READ_CALL_LOG permission is granted.
  Future<bool> checkPermission() async {
    if (!isPlatformSupported) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('checkPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests runtime call log permissions from the native operating system.
  Future<bool> requestPermission() async {
    if (!isPlatformSupported) return false;
    try {
      await _channel.invokeMethod('requestPermissions');
      // Verify granted status after requesting
      return await checkPermission();
    } catch (_) {
      return false;
    }
  }

  /// Fetches real device call logs from the native telephony provider.
  Future<List<DeviceCallLogItem>> fetchDeviceCallLogs({int limit = 100}) async {
    if (!isPlatformSupported) return [];

    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>(
        'getCallLogs',
        {'limit': limit},
      );
      if (rawList == null) return [];

      final items = <DeviceCallLogItem>[];
      for (final raw in rawList) {
        if (raw is Map) {
          items.add(DeviceCallLogItem.fromMap(raw));
        }
      }
      return items;
    } catch (e) {
      debugPrint('CallLogsRds.fetchDeviceCallLogs error: $e');
      return [];
    }
  }

  /// Streams saved call categorizations for the current executive to keep pills synced.
  Stream<Map<String, CallCategory>> streamSavedCategorizations() {
    final uid = currentUserId;
    Query<Map<String, dynamic>> query = _callCategorizations;
    if (uid != null && uid.isNotEmpty) {
      query = query.where('executiveUid', isEqualTo: uid);
    }

    return query.snapshots().map((snap) {
      final map = <String, CallCategory>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final cat = CallCategoryExtension.fromDbValue(
          data['category'] as String?,
        );
        final phoneNorm = (data['phoneNormalized'] ?? '').toString();
        final callId = (data['callId'] ?? doc.id).toString();

        if (phoneNorm.isNotEmpty) {
          map[phoneNorm] = cat;
        }
        if (callId.isNotEmpty) {
          map[callId] = cat;
        }
      }
      return map;
    });
  }

  /// Categorizes a call and persists the assignment in Firestore & CRM records.
  Future<void> saveCategorization({
    required DeviceCallLogItem item,
    required CallCategory category,
    String? notes,
  }) async {
    final uid = currentUserId ?? 'exec_user';
    final name = currentUserDisplayName;
    final norm = item.normalizedPhone;
    final docKey = norm.isNotEmpty ? norm : item.id;

    // 1. Persist categorization in `call_categorizations`
    await _callCategorizations.doc(docKey).set({
      'callId': item.id,
      'phone': item.number,
      'phoneNormalized': norm,
      'category': category.dbValue,
      'durationSeconds': item.durationSeconds,
      'callTimestamp': Timestamp.fromDate(item.timestamp),
      'categorizedAt': FieldValue.serverTimestamp(),
      'executiveUid': uid,
      'executiveName': name,
      'notes': notes ?? '',
    }, SetOptions(merge: true));

    // 2. Synchronize with Leads & Follow-ups collection
    if (norm.isEmpty) return;

    try {
      final phoneDoc = await _leadPhones.doc(norm).get();
      String? targetLeadId;

      if (phoneDoc.exists && phoneDoc.data() != null) {
        final pData = phoneDoc.data()!;
        targetLeadId = (pData['leadId'] ?? '').toString().trim();
      }

      if (targetLeadId != null && targetLeadId.isNotEmpty) {
        // Update existing lead status and category
        String statusUpdate = 'Interested';
        if (category == CallCategory.followUp) {
          statusUpdate = 'Follow-up';
        } else if (category == CallCategory.reminder) {
          statusUpdate = 'Follow-up';
        } else if (category == CallCategory.hotLead) {
          statusUpdate = 'Interested';
        }

        await _leads.doc(targetLeadId).update({
          'category': category.dbValue,
          'status': statusUpdate,
          'lastContact': 'Today · Categorized via Call Log',
          'lastContactAt': FieldValue.serverTimestamp(),
          'timeline': FieldValue.arrayUnion([
            '${LeadDateHelper.todayDateKey()} · Categorized as ${category.label} from Call Log by $name',
          ]),
        });
      } else {
        // Create new lead record assigned to this executive
        String leadStatus = 'Interested';
        if (category == CallCategory.followUp) {
          leadStatus = 'Follow-up';
        } else if (category == CallCategory.reminder) {
          leadStatus = 'Follow-up';
        }

        final created = await LeadsRds().createLead(
          name: '', // Generates next auto sequence e.g. L001
          phone: item.number,
          collegeBranch: 'Call Log Inquiry',
          source: 'Call Log',
          status: leadStatus,
          notes: 'Auto-categorized as ${category.label} from device call log.',
          assignToSelfAsWalkIn: true,
        );
        targetLeadId = created.id;

        await _leads.doc(created.id).update({
          'category': category.dbValue,
        });
      }

      // If Follow-up or Reminder, also schedule follow-up on the lead
      if (category == CallCategory.followUp || category == CallCategory.reminder) {
        final scheduledTime = DateTime.now().add(const Duration(days: 1)).copyWith(
          hour: category == CallCategory.reminder ? 11 : 10,
          minute: 30,
        );
        final timeLabel = LeadDateHelper.formatFollowUp(scheduledTime);

        await FollowUpsRds().snoozeFollowUp(
          targetLeadId,
          timeLabel,
        );
      }
    } catch (e) {
      debugPrint('CallLogsRds.saveCategorization lead sync error: $e');
    }
  }

  /// Streams leads filtered by specific category for the user Home screen.
  Stream<List<ExecutiveLeadItem>> streamLeadsByCategory(CallCategory category) {
    final uid = currentUserId;
    Query<Map<String, dynamic>> query = _leads.where(
      'category',
      isEqualTo: category.dbValue,
    );
    if (uid != null && uid.isNotEmpty) {
      query = query.where('assignedToUid', isEqualTo: uid);
    }

    return query.snapshots().map((snap) {
      return snap.docs.map((doc) {
        final d = doc.data();
        final rawPhone = (d['phone'] ?? '').toString();
        final masked = LeadPhoneValidator.maskPhone(rawPhone);
        final name = (d['name'] ?? 'Lead').toString();
        final status = (d['status'] ?? 'New').toString();
        final (sColor, sBg) = ExecutiveLeadItem.statusColorsFor(status);

        return ExecutiveLeadItem(
          id: doc.id,
          name: name,
          initials: LeadPhoneValidator.initialsFromName(name),
          maskedPhone: masked,
          fullPhone: rawPhone,
          collegeInfo: (d['collegeBranch'] ?? 'Inquiry').toString(),
          statusTag: status,
          statusColor: sColor,
          statusBg: sBg,
          campaignTag: (d['source'] ?? 'Call Log').toString(),
          followUpTime: (d['followUpTime'] ?? 'Tomorrow, 10:30 AM').toString(),
        );
      }).toList();
    });
  }
}
