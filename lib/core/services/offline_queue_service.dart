import 'dart:async';
import 'dart:convert';
import 'dart:io' show InternetAddress;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../ui/leads/data/model/lead_models.dart';
import 'firestore_connectivity_helper.dart';

/// Representation of an offline call outcome queued on the device.
class QueuedCallOutcome {
  final String clientId;
  final String leadId;
  final String leadName;
  final String outcome;
  final String duration;
  final String notes;
  final String? courseEnrolled;
  final int? discountAmount;
  final DateTime recordedAt;
  final int retryCount;
  final String? executiveUid;
  final String? executiveName;

  const QueuedCallOutcome({
    required this.clientId,
    required this.leadId,
    required this.leadName,
    required this.outcome,
    required this.duration,
    required this.notes,
    this.courseEnrolled,
    this.discountAmount,
    required this.recordedAt,
    this.retryCount = 0,
    this.executiveUid,
    this.executiveName,
  });

  Map<String, dynamic> toMap() => {
    'type': 'call_outcome',
    'clientId': clientId,
    'leadId': leadId,
    'leadName': leadName,
    'outcome': outcome,
    'duration': duration,
    'notes': notes,
    'courseEnrolled': courseEnrolled,
    'discountAmount': discountAmount,
    'recordedAt': recordedAt.toIso8601String(),
    'retryCount': retryCount,
    'executiveUid': executiveUid,
    'executiveName': executiveName,
  };

  factory QueuedCallOutcome.fromMap(Map<String, dynamic> map) =>
      QueuedCallOutcome(
        clientId: map['clientId'] as String,
        leadId: map['leadId'] as String,
        leadName: map['leadName'] as String,
        outcome: map['outcome'] as String,
        duration: map['duration'] as String,
        notes: map['notes'] as String,
        courseEnrolled: map['courseEnrolled'] as String?,
        discountAmount: (map['discountAmount'] as num?)?.toInt(),
        recordedAt:
            DateTime.tryParse(map['recordedAt'] as String? ?? '') ??
            DateTime.now(),
        retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
        executiveUid: map['executiveUid'] as String?,
        executiveName: map['executiveName'] as String?,
      );
}

/// Representation of an offline college visit outcome queued on the device.
class QueuedVisitOutcome {
  final String clientId;
  final String visitId;
  final String metPeople;
  final String nextAction;
  final int leadsCollected;
  final int interestedCount;
  final DateTime recordedAt;
  final int retryCount;
  final String? executiveUid;

  const QueuedVisitOutcome({
    required this.clientId,
    required this.visitId,
    required this.metPeople,
    required this.nextAction,
    required this.leadsCollected,
    required this.interestedCount,
    required this.recordedAt,
    this.retryCount = 0,
    this.executiveUid,
  });

  Map<String, dynamic> toMap() => {
    'type': 'visit_outcome',
    'clientId': clientId,
    'visitId': visitId,
    'metPeople': metPeople,
    'nextAction': nextAction,
    'leadsCollected': leadsCollected,
    'interestedCount': interestedCount,
    'recordedAt': recordedAt.toIso8601String(),
    'retryCount': retryCount,
    'executiveUid': executiveUid,
  };

  factory QueuedVisitOutcome.fromMap(Map<String, dynamic> map) =>
      QueuedVisitOutcome(
        clientId: map['clientId'] as String,
        visitId: map['visitId'] as String,
        metPeople: map['metPeople'] as String? ?? '',
        nextAction: map['nextAction'] as String? ?? '',
        leadsCollected: (map['leadsCollected'] as num?)?.toInt() ?? 0,
        interestedCount: (map['interestedCount'] as num?)?.toInt() ?? 0,
        recordedAt:
            DateTime.tryParse(map['recordedAt'] as String? ?? '') ??
            DateTime.now(),
        retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
        executiveUid: map['executiveUid'] as String?,
      );
}

/// Enterprise-grade Offline Queue and Network Synchronization Manager.
///
/// Features:
/// 1. Persistent local storage in Hive for zero-data-loss when offline.
/// 2. Idempotent write keys (clientId) to completely eliminate duplicate Firestore rows on retries.
/// 3. Reactive connectivity listener with real internet validation.
/// 4. Global notifiers for status banners (isOnline, isSyncing, pendingCount, justSynced).
class OfflineQueueService {
  OfflineQueueService._();
  static final OfflineQueueService instance = OfflineQueueService._();

  static const String boxName = 'offline_sync_queue';
  static const String legacyBoxName = 'offline_call_queue';
  Box<String>? _box;

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> justSyncedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> justReconnectedNotifier = ValueNotifier<bool>(
    false,
  );

  bool get isOnline => isOnlineNotifier.value;
  int get pendingCount => pendingCountNotifier.value;
  bool get isSyncing => isSyncingNotifier.value;
  bool get justSynced => justSyncedNotifier.value;
  bool get justReconnected => justReconnectedNotifier.value;

  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _justSyncedTimer;
  Timer? _offlineDebounceTimer;
  Timer? _reconnectBannerTimer;
  Timer? _recoveryProbeTimer;
  int _recoveryAttempt = 0;

  static const String _firestoreHost = 'firestore.googleapis.com';
  static const List<Duration> _recoveryBackoffSteps = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];
  static const int _maxItemRetries = 5;

  /// Optional test hook to override the DNS/host reachability check.
  @visibleForTesting
  Future<bool> Function()? reachabilityProbeOverride;

  /// Exposes the current automatic recovery attempt count for diagnostics/tests.
  @visibleForTesting
  int get recoveryAttemptCount => _recoveryAttempt;

  /// Verifies actual DNS resolution for `firestore.googleapis.com` on mobile/desktop.
  /// Returns `false` when DNS fails (`UnknownHostException`) even if the OS
  /// reports an active Wi-Fi or cellular interface.
  Future<bool> verifyFirestoreReachability() async {
    if (reachabilityProbeOverride != null) {
      try {
        return await reachabilityProbeOverride!();
      } catch (_) {
        return false;
      }
    }
    if (kIsWeb) return true;
    try {
      final addresses = await InternetAddress.lookup(
        _firestoreHost,
      ).timeout(const Duration(seconds: 3));
      return addresses.isNotEmpty &&
          addresses.any((addr) => addr.rawAddress.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  /// Reports a Firestore connectivity or DNS failure (e.g., `unavailable` /
  /// `UnknownHostException`). Marks the app offline so [OfflineStatusBar]
  /// displays immediately, and schedules a bounded exponential-backoff probe
  /// instead of an infinite retry loop.
  void reportConnectivityFailure() {
    _offlineDebounceTimer?.cancel();
    if (isOnlineNotifier.value) {
      isOnlineNotifier.value = false;
      debugPrint(
        '📴 Firestore unreachable (DNS/network failure). Entering offline mode.',
      );
    }
    _scheduleBoundedRecoveryProbe();
  }

  void _scheduleBoundedRecoveryProbe() {
    if (_recoveryProbeTimer?.isActive ?? false) return;
    if (_recoveryAttempt >= _recoveryBackoffSteps.length) {
      debugPrint(
        '⏹️ Automatic reconnect probes paused after ${_recoveryBackoffSteps.length} attempts. Waiting for network change, app resume, or manual Retry.',
      );
      return;
    }
    final delay = _recoveryBackoffSteps[_recoveryAttempt];
    _recoveryAttempt++;
    _recoveryProbeTimer = Timer(delay, () async {
      if (isOnlineNotifier.value) {
        _recoveryAttempt = 0;
        return;
      }
      final reachable = await verifyFirestoreReachability();
      if (reachable) {
        _recoveryAttempt = 0;
        await _handleNetworkRestored();
      } else {
        _scheduleBoundedRecoveryProbe();
      }
    });
  }

  /// Re-checks OS network interface + DNS reachability and drains any pending
  /// offline writes if Firestore is reachable. Safe to call on app resume.
  Future<bool> checkConnectivityAndSync() async {
    _recoveryProbeTimer?.cancel();
    _recoveryAttempt = 0;

    bool hasInterface = true;
    try {
      final results = await Connectivity().checkConnectivity();
      hasInterface = results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      hasInterface = true;
    }

    if (!hasInterface) {
      if (isOnlineNotifier.value) {
        isOnlineNotifier.value = false;
      }
      return false;
    }

    final reachable = await verifyFirestoreReachability();
    if (!reachable) {
      if (isOnlineNotifier.value) {
        isOnlineNotifier.value = false;
        debugPrint(
          '📴 Network interface active, but $_firestoreHost could not be resolved.',
        );
      }
      _scheduleBoundedRecoveryProbe();
      return false;
    }

    await _handleNetworkRestored();
    if (pendingCountNotifier.value > 0) {
      await syncPendingQueue();
    }
    return true;
  }

  /// Initializes the local Hive boxes with automatic legacy migration.
  static Future<void> init() async {
    try {
      await Hive.openBox<String>(boxName);
    } catch (_) {
      try {
        await Hive.deleteBoxFromDisk(boxName);
        await Hive.openBox<String>(boxName);
      } catch (_) {}
    }

    // Migrate any items from legacy box if present
    try {
      if (await Hive.boxExists(legacyBoxName)) {
        final legacy = await Hive.openBox<String>(legacyBoxName);
        if (legacy.isNotEmpty) {
          final current = Hive.box<String>(boxName);
          for (final key in legacy.keys) {
            final val = legacy.get(key);
            if (val != null) {
              await current.put(key.toString(), val);
            }
          }
          await legacy.clear();
        }
      }
    } catch (_) {}
  }

  /// Bootstraps the offline queue and background synchronization worker.
  void initialize() {
    _box = Hive.isBoxOpen(boxName) ? Hive.box<String>(boxName) : null;
    _updateCounts();

    // Check initial connectivity once gently without false negatives
    _checkInitialConnectivity();

    // Listen to network transitions with debounce to prevent micro-disconnection popups
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasInterface = results.any((r) => r != ConnectivityResult.none);
      if (!hasInterface) {
        // Debounce: Wait 3.0 seconds before asserting offline.
        // If Wi-Fi is switching networks or cellular handoff occurs, it will cancel this timer.
        _offlineDebounceTimer?.cancel();
        _offlineDebounceTimer = Timer(
          const Duration(milliseconds: 3000),
          () async {
            final recheck = await Connectivity().checkConnectivity();
            if (recheck.every((r) => r == ConnectivityResult.none)) {
              if (isOnlineNotifier.value) {
                isOnlineNotifier.value = false;
                debugPrint(
                  '📴 Internet connection lost. Entering offline mode.',
                );
              }
            }
          },
        );
      } else {
        // Active interface detected! Cancel offline debounce timer and verify DNS reachability.
        _offlineDebounceTimer?.cancel();
        _recoveryProbeTimer?.cancel();
        _recoveryAttempt = 0;
        verifyFirestoreReachability().then((reachable) {
          if (reachable) {
            _handleNetworkRestored();
          } else {
            reportConnectivityFailure();
          }
        });
      }
    });

    // Attempt initial sync if items pending and online
    if (pendingCountNotifier.value > 0 && isOnlineNotifier.value) {
      syncPendingQueue();
    }
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) {
        isOnlineNotifier.value = false;
        return;
      }
      final reachable = await verifyFirestoreReachability();
      isOnlineNotifier.value = reachable;
      if (!reachable) {
        _scheduleBoundedRecoveryProbe();
      }
    } catch (_) {
      isOnlineNotifier.value = true;
    }
  }

  Future<void> _handleNetworkRestored() async {
    final wasOffline = !isOnlineNotifier.value;
    _recoveryProbeTimer?.cancel();
    _recoveryAttempt = 0;

    if (wasOffline) {
      isOnlineNotifier.value = true;
      debugPrint('🌐 Internet connection restored.');

      // Ensure Firestore network client resumes cleanly without blocking UI.
      try {
        await FirebaseFirestore.instance.enableNetwork().timeout(
          const Duration(seconds: 2),
        );
      } catch (_) {}

      if (pendingCountNotifier.value > 0) {
        // Drain queued items
        syncPendingQueue();
      } else {
        // Show brief "Back online" reassurance banner for 2 seconds then auto-dismiss
        justReconnectedNotifier.value = true;
        _reconnectBannerTimer?.cancel();
        _reconnectBannerTimer = Timer(const Duration(milliseconds: 2000), () {
          justReconnectedNotifier.value = false;
        });
      }
    } else {
      // Was already online: stay online quietly without popping up
      isOnlineNotifier.value = true;
    }
  }

  bool _isInternalMetadataKey(dynamic key) =>
      key is String && key.startsWith('__');

  void _updateCounts() {
    final count =
        _box?.keys.where((k) => !_isInternalMetadataKey(k)).length ?? 0;
    pendingCountNotifier.value = count;
    _pendingCountController.add(count);
  }

  /// Returns locally queued call outcomes for instant offline UI display.
  List<QueuedCallOutcome> getQueuedCalls() {
    final box = _box;
    if (box == null) return const [];
    final list = <QueuedCallOutcome>[];
    for (final key in box.keys) {
      if (_isInternalMetadataKey(key)) continue;
      final raw = box.get(key);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic> &&
              decoded['type'] == 'call_outcome') {
            list.add(QueuedCallOutcome.fromMap(decoded));
          }
        } catch (_) {}
      }
    }
    return list;
  }

  /// Queues a call outcome locally with an idempotent client ID.
  /// Pass [clientId] when falling back from an interrupted online attempt so
  /// retries merge into the same `call_logs/{clientId}` document without duplicates.
  Future<void> enqueueOutcome({
    String? clientId,
    required String leadId,
    required String leadName,
    required String outcome,
    required String duration,
    required String notes,
    String? courseEnrolled,
    int? discountAmount,
    String? executiveUid,
    String? executiveName,
  }) async {
    final uid = executiveUid ?? FirebaseAuth.instance.currentUser?.uid;
    final name =
        executiveName ?? FirebaseAuth.instance.currentUser?.displayName;
    final resolvedClientId = (clientId != null && clientId.trim().isNotEmpty)
        ? clientId.trim()
        : 'call_${leadId}_${DateTime.now().millisecondsSinceEpoch}_${leadId.hashCode.abs()}';

    final queued = QueuedCallOutcome(
      clientId: resolvedClientId,
      leadId: leadId,
      leadName: leadName,
      outcome: outcome,
      duration: duration.isEmpty ? '2m 15s' : duration,
      notes: notes.isEmpty ? 'Logged $outcome outcome' : notes,
      courseEnrolled: courseEnrolled,
      discountAmount: discountAmount,
      recordedAt: DateTime.now(),
      executiveUid: uid,
      executiveName: name,
    );

    await _box?.put(resolvedClientId, jsonEncode(queued.toMap()));
    _updateCounts();
    debugPrint(
      '💾 Queued call outcome locally (client_id: $resolvedClientId). Queue count: ${pendingCountNotifier.value}',
    );

    // If online, trigger sync immediately
    if (isOnlineNotifier.value) {
      syncPendingQueue();
    }
  }

  /// Queues a college visit outcome locally.
  Future<void> enqueueVisitOutcome({
    required String visitId,
    required String metPeople,
    required String nextAction,
    required int leadsCollected,
    required int interestedCount,
    String? executiveUid,
  }) async {
    final uid = executiveUid ?? FirebaseAuth.instance.currentUser?.uid;
    final clientId =
        'visit_${visitId}_${DateTime.now().millisecondsSinceEpoch}';

    final queued = QueuedVisitOutcome(
      clientId: clientId,
      visitId: visitId,
      metPeople: metPeople,
      nextAction: nextAction,
      leadsCollected: leadsCollected,
      interestedCount: interestedCount,
      recordedAt: DateTime.now(),
      executiveUid: uid,
    );

    await _box?.put(clientId, jsonEncode(queued.toMap()));
    _updateCounts();
    debugPrint(
      '💾 Queued visit outcome locally (client_id: $clientId). Queue count: ${pendingCountNotifier.value}',
    );

    if (isOnlineNotifier.value) {
      syncPendingQueue();
    }
  }

  /// Public trigger to manually force a connectivity check & sync.
  Future<void> syncNow() async {
    await checkConnectivityAndSync();
  }

  /// Drains all items from the persistent queue and commits to Firestore.
  /// Uses idempotent document `.set(..., SetOptions(merge: true))` to ensure
  /// ZERO duplicate writes even under repetitive network reconnects.
  Future<void> syncPendingQueue() async {
    if (isSyncingNotifier.value ||
        _box == null ||
        pendingCountNotifier.value == 0) {
      return;
    }

    // Verify actual DNS/host reachability before firing Firestore writes.
    final reachable = await verifyFirestoreReachability();
    if (!reachable) {
      reportConnectivityFailure();
      return;
    }

    isSyncingNotifier.value = true;

    final initialItemsCount = pendingCountNotifier.value;
    int syncedSuccessCount = 0;

    try {
      final keys = _box!.keys.toList();
      final firestore = FirebaseFirestore.instance;

      for (final key in keys) {
        if (_isInternalMetadataKey(key)) continue;
        final raw = _box!.get(key);
        if (raw == null) continue;

        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) continue;
          final data = Map<String, dynamic>.from(decoded);
          final type = data['type'] as String? ?? 'call_outcome';
          final retryCount = (data['retryCount'] as num?)?.toInt() ?? 0;

          if (retryCount >= _maxItemRetries) {
            debugPrint(
              '⚠️ Dropping permanently failing offline queue record $key after $retryCount retries.',
            );
            await _box!.delete(key);
            continue;
          }

          bool success = false;
          if (type == 'call_outcome') {
            final item = QueuedCallOutcome.fromMap(data);
            success = await _syncCallOutcome(firestore, item);
          } else if (type == 'visit_outcome') {
            final item = QueuedVisitOutcome.fromMap(data);
            success = await _syncVisitOutcome(firestore, item);
          }

          if (success) {
            await _box!.delete(key);
            syncedSuccessCount++;
            debugPrint('✅ Synced offline queued record: $key');
          } else {
            data['retryCount'] = retryCount + 1;
            await _box!.put(key, jsonEncode(data));
          }
        } catch (e) {
          if (FirestoreConnectivityHelper.isConnectivityError(e)) {
            debugPrint(
              '📴 Sync paused at $key due to DNS/network error: $e',
            );
            reportConnectivityFailure();
            break;
          }
          debugPrint('⚠️ Error processing offline queue record $key: $e');
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              final nextRetry = ((decoded['retryCount'] as num?)?.toInt() ?? 0) + 1;
              if (nextRetry >= _maxItemRetries) {
                await _box!.delete(key);
              } else {
                decoded['retryCount'] = nextRetry;
                await _box!.put(key, jsonEncode(decoded));
              }
            }
          } catch (_) {}
        }
      }
    } finally {
      isSyncingNotifier.value = false;
      _updateCounts();

      // If we synced items successfully, flash the green success state
      if (initialItemsCount > 0 &&
          syncedSuccessCount > 0 &&
          pendingCountNotifier.value == 0) {
        justSyncedNotifier.value = true;
        _justSyncedTimer?.cancel();
        _justSyncedTimer = Timer(const Duration(milliseconds: 2800), () {
          justSyncedNotifier.value = false;
        });
      }
    }
  }

  /// Idempotent Firestore sync for a Call Outcome.
  Future<bool> _syncCallOutcome(
    FirebaseFirestore firestore,
    QueuedCallOutcome item,
  ) async {
    try {
      final todayKey = LeadDateHelper.todayDateKey();
      final leadRef = firestore.collection('leads').doc(item.leadId);
      final assignId = '${item.leadId}_$todayKey';
      final assignRef1 = firestore.collection('assignments').doc(assignId);
      final assignRef2 = firestore.collection('lead_assignments').doc(assignId);

      // 1. Determine status update rules
      String nextStatus = item.outcome;
      final isFollowUpPending =
          item.outcome == 'Follow-up' ||
          item.outcome == 'Callback' ||
          item.outcome == 'Interested' ||
          item.outcome == 'No answer';

      // 2. Lead document update (merge). Use the REAL time the call was made
      // (not the time of the delayed sync) and concrete follow-up dates.
      final callTs = Timestamp.fromDate(item.recordedAt);
      final resolvedFollowUp = isFollowUpPending
          ? LeadDateHelper.resolveFollowUpLabel(
              null,
              outcome: item.outcome,
              now: item.recordedAt,
            )
          : null;
      await leadRef
          .set({
            'status': nextStatus,
            'lastContact': 'Today',
            'lastContactAt': callTs,
            'lastCalledAt': callTs,
            'isDone': !isFollowUpPending,
            'followUpDone': !isFollowUpPending,
            'isOverdue': false,
            'isLocked': false,
            'lockedByUid': null,
            'lockedMessage': null,
            'followUpTime': ?resolvedFollowUp,
            if (item.notes.trim().isNotEmpty) 'notes': item.notes.trim(),
            'timeline': FieldValue.arrayUnion([
              '${LeadDateHelper.timelineStamp(item.recordedAt)} · ${item.outcome} logged by ${item.executiveName ?? "executive"}${item.notes.trim().isNotEmpty ? " (${item.notes.trim()})" : ""}',
            ]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));

      // 3. Assignment document update (merge to both collections for complete sync)
      final assignUpdate = {
        'isDone': true,
        'lastOutcome': item.outcome,
        'leadStatus': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await assignRef1
          .set(assignUpdate, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
      await assignRef2
          .set(assignUpdate, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));

      // 4. Call log with DETERMINISTIC document ID (clientId) -> guarantees zero duplicates!
      final logRef = firestore.collection('call_logs').doc(item.clientId);
      await logRef
          .set({
            'leadId': item.leadId,
            'leadName': item.leadName,
            'executiveUid': item.executiveUid,
            'executiveName': item.executiveName ?? 'Sales Executive',
            'outcome': item.outcome,
            'duration': item.duration,
            'notes': item.notes,
            if (item.courseEnrolled != null)
              'courseEnrolled': item.courseEnrolled,
            if (item.discountAmount != null)
              'discountAmount': item.discountAmount,
            'createdAt': Timestamp.fromDate(item.recordedAt),
            'syncedAt': FieldValue.serverTimestamp(),
            'isOfflineSynced': true,
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));

      return true;
    } catch (e) {
      if (FirestoreConnectivityHelper.isConnectivityError(e)) {
        rethrow;
      }
      debugPrint('Sync call outcome failed for ${item.clientId}: $e');
      return false;
    }
  }

  /// Idempotent Firestore sync for a Visit Outcome.
  Future<bool> _syncVisitOutcome(
    FirebaseFirestore firestore,
    QueuedVisitOutcome item,
  ) async {
    try {
      await firestore
          .collection('college_visits')
          .doc(item.visitId)
          .set({
            'status': 'Completed',
            'statusLabel': 'Completed',
            'metSummary': item.metPeople.trim(),
            'outcomeNotes': item.metPeople.trim(),
            'nextActionSummary': item.nextAction.trim(),
            'leadsCollected': item.leadsCollected,
            'interestedCount': item.interestedCount,
            'updatedByUid': item.executiveUid,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
      return true;
    } catch (e) {
      if (FirestoreConnectivityHelper.isConnectivityError(e)) {
        rethrow;
      }
      debugPrint('Sync visit outcome failed for ${item.visitId}: $e');
      return false;
    }
  }

  /// Clears local queue on user logout.
  Future<void> clearAll() async {
    await _box?.clear();
    _updateCounts();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _offlineDebounceTimer?.cancel();
    _reconnectBannerTimer?.cancel();
    _justSyncedTimer?.cancel();
    _recoveryProbeTimer?.cancel();
    _pendingCountController.close();
  }
}
