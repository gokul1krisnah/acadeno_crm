import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../router/app_router.dart';

/// Multiplexes and caches Firestore `.snapshots()` streams across the application.
///
/// Why this is essential on Flutter Web (`@firebase/firestore` 13.1.0):
/// 1. Rapidly subscribing and unsubscribing to the same Firestore query target, OR
/// 2. Calling `.get()` (`getDoc` / `getDocs`) on a document/collection while a
///    `.snapshots()` (`onSnapshot`) listener is being established on the same path
/// causes `EventManager` / `WatchChangeAggregator` in `firebase-firestore-pipelines.js`
/// to decrement `TargetState.We` (`outstandingResponses`) to `-1`, throwing:
/// `INTERNAL ASSERTION FAILED: Unexpected state (ID: ca9 / ID: b815) {"We":-1}`.
///
/// By routing both live streams (`watchCollection` / `watchDoc` / `watchQuery`)
/// AND point reads (`getCollection` / `getDoc`) through a single persistent
/// shared subscription per path, Firestore JS SDK never experiences target churn
/// or concurrent `getDoc` + `onSnapshot` target collisions.
class FirestoreStreamCache {
  FirestoreStreamCache._();

  static final FirestoreStreamCache instance = FirestoreStreamCache._();

  final Map<String, _SharedReplayStream<QuerySnapshot<Map<String, dynamic>>>>
  _queryCache = {};

  final Map<String, _SharedReplayStream<DocumentSnapshot<Map<String, dynamic>>>>
  _docCache = {};

  _SharedReplayStream<QuerySnapshot<Map<String, dynamic>>> _getOrCreateCollection(
    String collectionPath, {
    FirebaseFirestore? firestore,
  }) {
    final db = firestore ?? FirebaseFirestore.instance;
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}

    final bool scopeToExecutive =
        !isAdminSession &&
        uid != null &&
        uid.isNotEmpty &&
        (collectionPath == 'leads' || collectionPath == 'call_categorizations');

    final String ownerField = collectionPath == 'call_categorizations'
        ? 'executiveUid'
        : 'assignedToUid';

    final key = scopeToExecutive
        ? 'col:$collectionPath:exec:$uid'
        : 'col:$collectionPath';

    return _queryCache.putIfAbsent(
      key,
      () => _SharedReplayStream<QuerySnapshot<Map<String, dynamic>>>(
        () => scopeToExecutive
            ? db
                  .collection(collectionPath)
                  .where(ownerField, isEqualTo: uid)
                  .snapshots()
            : db.collection(collectionPath).snapshots(),
        fallbackOnPermissionDenied:
            (!scopeToExecutive &&
                uid != null &&
                uid.isNotEmpty &&
                (collectionPath == 'leads' ||
                    collectionPath == 'call_categorizations'))
            ? () => db
                  .collection(collectionPath)
                  .where(ownerField, isEqualTo: uid)
                  .snapshots()
            : null,
      ),
    );
  }

  _SharedReplayStream<DocumentSnapshot<Map<String, dynamic>>> _getOrCreateDoc(
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
    );
  }

  /// Returns a shared, replay-enabled stream for a top-level collection.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCollection(
    String collectionPath, {
    FirebaseFirestore? firestore,
  }) {
    return _getOrCreateCollection(collectionPath, firestore: firestore).stream;
  }

  /// Returns the latest snapshot for a top-level collection without opening
  /// a competing one-shot `.get()` target in Firestore JS SDK.
  Future<QuerySnapshot<Map<String, dynamic>>> getCollection(
    String collectionPath, {
    FirebaseFirestore? firestore,
  }) {
    return _getOrCreateCollection(
      collectionPath,
      firestore: firestore,
    ).firstSnapshot();
  }

  /// Returns a shared, replay-enabled stream for a specific document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDoc(
    String collectionPath,
    String docId, {
    FirebaseFirestore? firestore,
  }) {
    return _getOrCreateDoc(collectionPath, docId, firestore: firestore).stream;
  }

  /// Returns the latest snapshot for a specific document without opening
  /// a competing one-shot `.get()` target in Firestore JS SDK.
  Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(
    String collectionPath,
    String docId, {
    FirebaseFirestore? firestore,
  }) {
    return _getOrCreateDoc(
      collectionPath,
      docId,
      firestore: firestore,
    ).firstSnapshot();
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
  final Stream<T> Function()? fallbackOnPermissionDenied;
  StreamSubscription<T>? _sourceSub;
  final Set<MultiStreamController<T>> _listeners = {};
  final List<Completer<T>> _pendingFirsts = [];
  T? _latestValue;
  bool _hasValue = false;
  bool _isDisposed = false;
  bool _usedFallback = false;

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

  _SharedReplayStream(this._sourceFactory, {this.fallbackOnPermissionDenied});

  Future<T> firstSnapshot() {
    if (_hasValue && _latestValue != null) {
      return Future<T>.value(_latestValue as T);
    }
    _ensureSubscribed();
    final completer = Completer<T>();
    _pendingFirsts.add(completer);
    return completer.future;
  }

  void _ensureSubscribed() {
    if (_sourceSub != null || _isDisposed) return;
    _subscribeWith(_usedFallback && fallbackOnPermissionDenied != null
        ? fallbackOnPermissionDenied!
        : _sourceFactory);
  }

  void _subscribeWith(Stream<T> Function() factory) {
    try {
      _sourceSub = factory().listen(
        (data) {
          _latestValue = data;
          _hasValue = true;
          if (_pendingFirsts.isNotEmpty) {
            for (final c in _pendingFirsts) {
              if (!c.isCompleted) c.complete(data);
            }
            _pendingFirsts.clear();
          }
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
            return;
          }
          final isPermDenied =
              (error is FirebaseException &&
                  error.code == 'permission-denied') ||
              msg.toLowerCase().contains('permission-denied') ||
              msg.toLowerCase().contains('permission_denied');
          if (isPermDenied &&
              !_usedFallback &&
              fallbackOnPermissionDenied != null &&
              !_isDisposed) {
            _usedFallback = true;
            final oldSub = _sourceSub;
            _sourceSub = null;
            oldSub?.cancel();
            _subscribeWith(fallbackOnPermissionDenied!);
            return;
          }
          debugPrint('[FirestoreStreamCache] Stream notice: $error');
          if (_pendingFirsts.isNotEmpty) {
            for (final c in _pendingFirsts) {
              if (!c.isCompleted) c.completeError(error, stack);
            }
            _pendingFirsts.clear();
          }
          for (final listener in _listeners.toList()) {
            if (!listener.isClosed) {
              listener.addError(error, stack);
            }
          }
        },
      );
    } catch (e, st) {
      debugPrint('[FirestoreStreamCache] Subscribe notice: $e');
      if (_pendingFirsts.isNotEmpty) {
        for (final c in _pendingFirsts) {
          if (!c.isCompleted) c.completeError(e, st);
        }
        _pendingFirsts.clear();
      }
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
    _pendingFirsts.clear();
    try {
      await sub?.cancel();
    } catch (_) {}
  }
}
