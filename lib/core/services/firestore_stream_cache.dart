import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Multiplexes and caches Firestore `.snapshots()` streams across the application.
///
/// Why this is essential on Flutter Web (`@firebase/firestore` 13.1.0):
/// Rapidly subscribing and unsubscribing to the same Firestore query target
/// (e.g. inside `StreamBuilder` during `LayoutBuilder` / `MediaQuery` resizes,
/// tab switches, or multiple widgets listening to the same collection) triggers
/// the Firestore JS SDK internal assertion failure:
/// `INTERNAL ASSERTION FAILED: Unexpected state (ID: ca9 / ID: b815) {"We":-1}`.
///
/// By keeping a single persistent underlying subscription per query key and
/// multiplexing snapshots in Dart memory with latest-value replay:
/// 1. `watchCollection` / `watchDoc` / `watchQuery` always return the exact
///    same `Stream` instance for a given key, so `StreamBuilder` never churns
///    subscriptions across rebuilds.
/// 2. Mounting/unmounting widgets or switching tabs attaches/detaches purely
///    in Dart memory without sending `RemoveTarget` / `AddTarget` packets to
///    the Firestore JS WatchChangeAggregator.
class FirestoreStreamCache {
  FirestoreStreamCache._();

  static final FirestoreStreamCache instance = FirestoreStreamCache._();

  final Map<String, _SharedReplayStream<QuerySnapshot<Map<String, dynamic>>>>
  _queryCache = {};

  final Map<String, _SharedReplayStream<DocumentSnapshot<Map<String, dynamic>>>>
  _docCache = {};

  /// Returns a shared, replay-enabled stream for a top-level collection.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCollection(
    String collectionPath, {
    FirebaseFirestore? firestore,
  }) {
    final db = firestore ?? FirebaseFirestore.instance;
    final key = 'col:$collectionPath';
    return _queryCache.putIfAbsent(
      key,
      () => _SharedReplayStream<QuerySnapshot<Map<String, dynamic>>>(
        () => db.collection(collectionPath).snapshots(),
      ),
    ).stream;
  }

  /// Returns a shared, replay-enabled stream for a specific document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDoc(
    String collectionPath,
    String docId, {
    FirebaseFirestore? firestore,
  }) {
    final db = firestore ?? FirebaseFirestore.instance;
    final key = 'doc:$collectionPath/$docId';
    return _docCache.putIfAbsent(
      key,
      () => _SharedReplayStream<DocumentSnapshot<Map<String, dynamic>>>(
        () => db.collection(collectionPath).doc(docId).snapshots(),
      ),
    ).stream;
  }

  /// Returns a shared, replay-enabled stream for a filtered/ordered query.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchQuery(
    String cacheKey,
    Query<Map<String, dynamic>> Function() queryBuilder,
  ) {
    final key = 'query:$cacheKey';
    return _queryCache.putIfAbsent(
      key,
      () => _SharedReplayStream<QuerySnapshot<Map<String, dynamic>>>(
        () => queryBuilder().snapshots(),
      ),
    ).stream;
  }

  /// Disposes all cached Firestore subscriptions (call on sign-out).
  Future<void> clearAll() async {
    final queries = _queryCache.values.toList();
    final docs = _docCache.values.toList();
    _queryCache.clear();
    _docCache.clear();
    for (final q in queries) {
      await q.dispose();
    }
    for (final d in docs) {
      await d.dispose();
    }
  }
}

class _SharedReplayStream<T> {
  final Stream<T> Function() _sourceFactory;
  StreamSubscription<T>? _sourceSub;
  final Set<MultiStreamController<T>> _listeners = {};
  T? _latestValue;
  bool _hasValue = false;
  bool _isDisposed = false;

  late final Stream<T> stream = Stream<T>.multi((controller) {
    if (_isDisposed) {
      controller.close();
      return;
    }

    _listeners.add(controller);
    _ensureSubscribed();

    if (_hasValue && _latestValue != null) {
      final cached = _latestValue as T;
      scheduleMicrotask(() {
        if (!controller.isClosed && _listeners.contains(controller)) {
          controller.add(cached);
        }
      });
    }

    controller.onCancel = () {
      _listeners.remove(controller);
    };
  }, isBroadcast: true);

  _SharedReplayStream(this._sourceFactory);

  void _ensureSubscribed() {
    if (_sourceSub != null || _isDisposed) return;
    try {
      _sourceSub = _sourceFactory().listen(
        (data) {
          _latestValue = data;
          _hasValue = true;
          for (final listener in _listeners.toList()) {
            if (!listener.isClosed) {
              listener.add(data);
            }
          }
        },
        onError: (Object error, StackTrace stack) {
          final msg = error.toString();
          if (msg.contains('INTERNAL ASSERTION FAILED') ||
              msg.contains('b815') ||
              msg.contains('ca9')) {
            // Suppress internal Firestore JS SDK assertion noise from crashing listeners
            return;
          }
          debugPrint('[FirestoreStreamCache] Stream notice: $error');
          for (final listener in _listeners.toList()) {
            if (!listener.isClosed) {
              listener.addError(error, stack);
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[FirestoreStreamCache] Subscribe notice: $e');
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    final sub = _sourceSub;
    _sourceSub = null;
    for (final listener in _listeners.toList()) {
      if (!listener.isClosed) {
        listener.close();
      }
    }
    _listeners.clear();
    try {
      await sub?.cancel();
    } catch (_) {}
  }
}

