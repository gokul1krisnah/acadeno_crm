import 'dart:async';
import 'dart:io';

import 'package:acadeno_crm/core/services/firestore_connectivity_helper.dart';
import 'package:acadeno_crm/core/services/offline_queue_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreConnectivityHelper', () {
    test('detects UnknownHostException and unavailable Firestore errors', () {
      expect(
        FirestoreConnectivityHelper.isConnectivityError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message:
                'UNAVAILABLE: Unable to resolve host firestore.googleapis.com',
          ),
        ),
        isTrue,
      );

      expect(
        FirestoreConnectivityHelper.isConnectivityError(
          Exception(
            'io.grpc.StatusException: UNAVAILABLE: Unable to resolve host firestore.googleapis.com (UnknownHostException)',
          ),
        ),
        isTrue,
      );

      expect(
        FirestoreConnectivityHelper.isConnectivityError(
          const SocketException('Failed host lookup: firestore.googleapis.com'),
        ),
        isTrue,
      );

      expect(
        FirestoreConnectivityHelper.isConnectivityError(
          TimeoutException('Timed out waiting for Firestore'),
        ),
        isTrue,
      );
    });

    test('does not misclassify permission or validation errors as offline', () {
      expect(
        FirestoreConnectivityHelper.isConnectivityError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Missing or insufficient permissions.',
          ),
        ),
        isFalse,
      );

      expect(
        FirestoreConnectivityHelper.isConnectivityError(
          ArgumentError('Invalid phone number'),
        ),
        isFalse,
      );
    });

    test('returns clear user-friendly message for DNS/offline errors', () {
      final err = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Unable to resolve host firestore.googleapis.com',
      );
      expect(
        FirestoreConnectivityHelper.userFriendlyMessage(err),
        FirestoreConnectivityHelper.offlineMessage,
      );

      final permErr = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
      expect(
        FirestoreConnectivityHelper.userFriendlyMessage(permErr),
        'Missing or insufficient permissions.',
      );
    });
  });

  group('OfflineQueueService connectivity resilience', () {
    setUp(() {
      OfflineQueueService.instance.suppressDebugLogs = true;
    });

    tearDown(() {
      final svc = OfflineQueueService.instance;
      svc.resetRecoveryStateForTest();
      svc.reachabilityProbeOverride = null;
      svc.suppressDebugLogs = false;
      svc.isOnlineNotifier.value = true;
    });

    test('reportConnectivityFailure marks service offline and starts bounded recovery', () async {
      final svc = OfflineQueueService.instance;
      svc.isOnlineNotifier.value = true;
      svc.reachabilityProbeOverride = () async => false;

      svc.reportConnectivityFailure();
      expect(svc.isOnline, isFalse);
      expect(svc.recoveryAttemptCount, greaterThanOrEqualTo(1));
      expect(svc.recoveryAttemptCount, lessThanOrEqualTo(4));
    });

    test('verifyFirestoreReachability reflects DNS probe outcome', () async {
      final svc = OfflineQueueService.instance;

      svc.reachabilityProbeOverride = () async => false;
      expect(await svc.verifyFirestoreReachability(), isFalse);

      svc.reachabilityProbeOverride = () async => true;
      expect(await svc.verifyFirestoreReachability(), isTrue);
    });
  });
}
