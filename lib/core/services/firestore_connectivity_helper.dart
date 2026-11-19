import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'offline_queue_service.dart';

/// Shared helper to identify transient Firestore / DNS / network connectivity
/// errors, surface clear user-facing messages, and keep [OfflineQueueService]
/// accurately synchronized when DNS resolution fails even on an active Wi-Fi or
/// cellular interface.
class FirestoreConnectivityHelper {
  FirestoreConnectivityHelper._();

  static const String offlineMessage =
      'Unable to reach server. Check your internet/DNS connection and try again.';

  /// Returns `true` when [error] represents a transient network, DNS
  /// (`UnknownHostException`), timeout, or Firestore `unavailable` condition.
  static bool isConnectivityError(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return true;
    }
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      if (code == 'unavailable' ||
          code == 'deadline-exceeded' ||
          code == 'network-request-failed') {
        return true;
      }
    }

    final lower = error.toString().toLowerCase();
    return lower.contains('unable to resolve host') ||
        lower.contains('unknownhostexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('client is offline') ||
        lower.contains('cloud_firestore/unavailable') ||
        lower.contains('unavailable:');
  }

  /// Notifies [OfflineQueueService] if [error] is a connectivity/DNS failure so
  /// the global offline banner becomes visible without waiting for OS interface
  /// drop events.
  static bool reportIfConnectivityError(Object error) {
    if (!isConnectivityError(error)) return false;
    OfflineQueueService.instance.reportConnectivityFailure();
    return true;
  }

  /// Formats [error] into a concise, human-readable message. Connectivity and
  /// DNS failures always return a clear offline hint instead of raw gRPC logs.
  static String userFriendlyMessage(Object error, {String? fallback}) {
    if (isConnectivityError(error)) {
      return offlineMessage;
    }
    if (error is FirebaseException) {
      final msg = error.message?.trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    final cleaned = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Bad state: ', '')
        .trim();
    if (cleaned.isNotEmpty) return cleaned;
    return fallback ?? 'Something went wrong. Please try again.';
  }
}
