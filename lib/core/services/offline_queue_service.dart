import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Representation of an offline call outcome queued on the device (RL-5, RL-6).
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
  });

  Map<String, dynamic> toMap() => {
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
  };

  factory QueuedCallOutcome.fromMap(Map<String, dynamic> map) => QueuedCallOutcome(
    clientId: map['clientId'] as String,
    leadId: map['leadId'] as String,
    leadName: map['leadName'] as String,
    outcome: map['outcome'] as String,
    duration: map['duration'] as String,
    notes: map['notes'] as String,
    courseEnrolled: map['courseEnrolled'] as String?,
    discountAmount: (map['discountAmount'] as num?)?.toInt(),
    recordedAt: DateTime.tryParse(map['recordedAt'] as String? ?? '') ?? DateTime.now(),
    retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
  );
}

/// Manages offline persistence and automatic background queue synchronization (RL-5, RL-6).
class OfflineQueueService {
  OfflineQueueService._();
  static final OfflineQueueService instance = OfflineQueueService._();

  static const String boxName = 'offline_call_queue';
  Box<String>? _box;

  final StreamController<int> _pendingCountController = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  Future<bool> Function(QueuedCallOutcome item)? _syncHandler;

  /// Initializes the encrypted/local queue box in Hive.
  static Future<void> init() async {
    try {
      await Hive.openBox<String>(boxName);
    } catch (_) {
      try {
        await Hive.deleteBoxFromDisk(boxName);
        await Hive.openBox<String>(boxName);
      } catch (_) {}
    }
  }

  void initialize({required Future<bool> Function(QueuedCallOutcome item) syncHandler}) {
    _syncHandler = syncHandler;
    _box = Hive.isBoxOpen(boxName) ? Hive.box<String>(boxName) : null;
    _notifyCount();

    // Listen for connectivity changes to trigger automatic sync
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && pendingCount > 0) {
        syncPendingQueue();
      }
    });

    // Attempt initial sync on app start
    if (pendingCount > 0) {
      syncPendingQueue();
    }
  }

  int get pendingCount => _box?.length ?? 0;

  void _notifyCount() {
    _pendingCountController.add(pendingCount);
  }

  /// Queues an outcome locally with a unique client ID.
  Future<void> enqueueOutcome({
    required String leadId,
    required String leadName,
    required String outcome,
    required String duration,
    required String notes,
    String? courseEnrolled,
    int? discountAmount,
  }) async {
    final clientId = 'cl_${DateTime.now().millisecondsSinceEpoch}_${leadId.hashCode.abs()}';
    final queued = QueuedCallOutcome(
      clientId: clientId,
      leadId: leadId,
      leadName: leadName,
      outcome: outcome,
      duration: duration,
      notes: notes,
      courseEnrolled: courseEnrolled,
      discountAmount: discountAmount,
      recordedAt: DateTime.now(),
    );

    await _box?.put(clientId, jsonEncode(queued.toMap()));
    _notifyCount();
    debugPrint('💾 Queued call outcome locally (client_id: $clientId). Queue count: $pendingCount');

    // Attempt immediate sync if connected
    syncPendingQueue();
  }

  /// Drains all items from the queue and syncs to backend.
  Future<void> syncPendingQueue() async {
    if (_isSyncing || _syncHandler == null || _box == null || pendingCount == 0) return;
    _isSyncing = true;

    try {
      final keys = _box!.keys.toList();
      for (final key in keys) {
        final raw = _box!.get(key);
        if (raw == null) continue;

        try {
          final item = QueuedCallOutcome.fromMap(jsonDecode(raw) as Map<String, dynamic>);
          final success = await _syncHandler!(item);
          if (success) {
            await _box!.delete(key);
            debugPrint('✅ Synced offline call outcome for ${item.leadName}');
          }
        } catch (e) {
          debugPrint('⚠️ Retry needed for item $key: $e');
        }
      }
    } finally {
      _isSyncing = false;
      _notifyCount();
    }
  }

  /// Wipes all local offline data on logout (PR-6.3).
  Future<void> clearAll() async {
    await _box?.clear();
    _notifyCount();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pendingCountController.close();
  }
}

