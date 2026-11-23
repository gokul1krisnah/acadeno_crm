import 'dart:async';
import 'dart:io';

import 'package:acadeno_crm/core/services/crm_ai_assistant_service.dart';
import 'package:acadeno_crm/core/services/offline_queue_service.dart';
import 'package:acadeno_crm/shared/widgets/ai_chat_assistant.dart';
import 'package:acadeno_crm/ui/leads/data/model/lead_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCrmAiDataProvider implements CrmAiDataProvider {
  bool isSignedIn = true;
  bool throwNetworkError = false;
  int followUpsCalls = 0;
  int hotLeadsCalls = 0;
  int remindersCalls = 0;
  int assignedLeadsCalls = 0;

  static final ExecutiveLeadItem sampleLead = ExecutiveLeadItem(
    id: 'lead_101',
    name: 'Jishnu',
    initials: 'J',
    maskedPhone: '+91 98765 •••10',
    fullPhone: '9876543210',
    collegeInfo: 'Plus Two',
    statusTag: 'Follow-up',
    statusColor: const Color(0xFF3730A3),
    statusBg: const Color(0xFFE8EDFF),
    campaignTag: 'Social Media',
    followUpTime: 'Today, 4:00 PM',
  );

  static final CrmAiRecordReference sampleRef = CrmAiRecordReference(
    id: 'lead_101',
    displayName: 'Jishnu',
    subtitle: 'Plus Two · Follow-up',
    leadItem: sampleLead,
  );

  @override
  String? get currentUserId => isSignedIn ? 'exec_uid_1' : null;

  @override
  Future<CrmAiActorContext> verifyCurrentActor() async {
    if (!isSignedIn) {
      throw const CrmAiAssistantException(
        CrmAiErrorKind.permission,
        'Permission error: Please sign in to use the AI Assistant.',
      );
    }
    if (throwNetworkError) {
      throw const SocketException('Failed host lookup: firestore.googleapis.com');
    }
    return const CrmAiActorContext(
      uid: 'exec_uid_1',
      displayName: 'Executive One',
      role: 'sales_executive',
      isAdminOrManager: false,
    );
  }

  @override
  Future<({Map<String, Object?> payload, List<CrmAiRecordReference> refs})>
  fetchFollowUpsContext() async {
    followUpsCalls++;
    return (
      payload: <String, Object?>{
        'dueTodayCount': 1,
        'overdueCount': 0,
        'dueTodayFollowUps': [
          {
            'refId': 'lead_101',
            'name': 'Jishnu',
            'collegeBranch': 'Plus Two',
            'status': 'Follow-up',
          },
        ],
      },
      refs: [sampleRef],
    );
  }

  @override
  Future<({Map<String, Object?> payload, List<CrmAiRecordReference> refs})>
  fetchHotLeadsContext() async {
    hotLeadsCalls++;
    return (
      payload: const <String, Object?>{
        'hotLeadsCount': 0,
        'hotLeads': <Object>[],
      },
      refs: const <CrmAiRecordReference>[],
    );
  }

  @override
  Future<({Map<String, Object?> payload, List<CrmAiRecordReference> refs})>
  fetchRemindersContext() async {
    remindersCalls++;
    return (
      payload: const <String, Object?>{
        'remindersCount': 0,
        'reminders': <Object>[],
      },
      refs: const <CrmAiRecordReference>[],
    );
  }

  @override
  Future<({Map<String, Object?> payload, List<CrmAiRecordReference> refs})>
  fetchAssignedLeadsContext({String? query, String? status}) async {
    assignedLeadsCalls++;
    return (
      payload: <String, Object?>{
        'totalPermittedLeads': 1,
        'leads': [
          {
            'refId': 'lead_101',
            'name': 'Jishnu',
            'collegeBranch': 'Plus Two',
            'status': 'Follow-up',
          },
        ],
      },
      refs: [sampleRef],
    );
  }

  @override
  Future<Map<String, Object?>> fetchCollegeVisitsContext() async {
    return const <String, Object?>{'visitsCount': 0, 'visits': <Object>[]};
  }

  @override
  Map<String, Object?> fetchWalkInLeadGuide() {
    return const <String, Object?>{
      'assistantMode': 'read_only',
      'steps': ['Tap + Add Leads on the Today screen.'],
    };
  }
}

class _FakeChatTransport implements CrmAiChatTransport {
  Object? errorToThrow;
  bool unregisteredTokenLatched = false;
  int sendAttempts = 0;
  final List<String> receivedMessages = [];

  @override
  void allowManualRetry() {
    unregisteredTokenLatched = false;
  }

  @override
  Stream<String> sendChatMessageStream({
    required String userMessage,
    required Map<String, Object?> groundedContext,
    required CrmAiActorContext actor,
  }) async* {
    if (unregisteredTokenLatched) {
      throw CrmAiAssistantService.buildAppCheckException(isDebugOverride: true);
    }
    sendAttempts++;
    receivedMessages.add(userMessage);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (errorToThrow != null) {
      if (CrmAiAssistantService.isAppCheckError(errorToThrow!)) {
        unregisteredTokenLatched = true;
      }
      throw errorToThrow!;
    }

    final lower = userMessage.toLowerCase();
    if (lower.contains('follow-up')) {
      yield 'You have 1 follow-up due today: ';
      await Future<void>.delayed(const Duration(milliseconds: 60));
      yield 'Jishnu (Plus Two) [Ref: lead_101].';
      return;
    }
    if (lower.contains('hot')) {
      yield 'You currently have 0 hot leads in your permitted CRM records.';
      return;
    }
    if (lower.contains('walk-in')) {
      yield 'I am read-only, so I cannot create leads directly. Tap + Add Leads on the Today screen to add a walk-in lead.';
      return;
    }
    yield 'Grounded answer for ${actor.displayName}: Jishnu [Ref: lead_101].';
  }

  @override
  void resetSession() {
    receivedMessages.clear();
    unregisteredTokenLatched = false;
    sendAttempts = 0;
  }
}

void main() {
  group('CrmAiAssistantService grounding, scoping & error classification', () {
    setUp(() {
      OfflineQueueService.instance.suppressDebugLogs = true;
    });

    tearDown(() {
      OfflineQueueService.instance.resetRecoveryStateForTest();
      OfflineQueueService.instance.suppressDebugLogs = false;
      OfflineQueueService.instance.isOnlineNotifier.value = true;
    });
    test('fetches only scoped follow-ups context and extracts record reference', () async {
      final provider = _FakeCrmAiDataProvider();
      final transport = _FakeChatTransport();
      final service = CrmAiAssistantService(
        dataProvider: provider,
        transport: transport,
      );

      final chunks = await service
          .sendMessageStream('Today’s follow-ups')
          .toList();

      expect(provider.followUpsCalls, 1);
      expect(provider.hotLeadsCalls, 0);
      expect(provider.remindersCalls, 0);
      expect(chunks.last.isDone, isTrue);
      expect(chunks.last.accumulatedText, contains('Jishnu (Plus Two)'));
      expect(chunks.last.accumulatedText, isNot(contains('#lead_101')));
      expect(chunks.last.accumulatedText, isNot(contains('[Ref:')));
      expect(chunks.last.references.length, 1);
      expect(chunks.last.references.first.id, 'lead_101');
    });

    test('enforces authentication and classifies quota, permission, and network errors', () async {
      final provider = _FakeCrmAiDataProvider()..isSignedIn = false;
      final transport = _FakeChatTransport();
      final service = CrmAiAssistantService(
        dataProvider: provider,
        transport: transport,
      );

      await expectLater(
        service.sendMessageStream('Hot leads').toList(),
        throwsA(
          isA<CrmAiAssistantException>().having(
            (e) => e.kind,
            'kind',
            CrmAiErrorKind.permission,
          ),
        ),
      );

      expect(
        CrmAiAssistantService.classifyError(QuotaExceeded('429 quota')).kind,
        CrmAiErrorKind.quota,
      );
      expect(
        CrmAiAssistantService.classifyError(
          FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        ).kind,
        CrmAiErrorKind.permission,
      );
      expect(
        CrmAiAssistantService.classifyError(
          const SocketException('Failed host lookup'),
        ).kind,
        CrmAiErrorKind.network,
      );

      // App Check debug token error classification & token redaction
      final rawAppCheckErr = FirebaseException(
        plugin: 'firebase_app_check',
        code: 'unknown',
        message:
            'Failed to exchange debug token (6a718e2d-f5bf-420a-af08-95802b1a43b6). Too many attempts.',
      );
      final classifiedAppCheck = CrmAiAssistantService.classifyError(
        rawAppCheckErr,
        isDebugOverride: true,
      );
      expect(classifiedAppCheck.kind, CrmAiErrorKind.appCheck);
      expect(
        classifiedAppCheck.message,
        contains('Manage debug tokens'),
      );
      expect(
        classifiedAppCheck.message,
        isNot(contains('6a718e2d-f5bf-420a-af08-95802b1a43b6')),
      );
      expect(
        CrmAiAssistantService.redactTokens(rawAppCheckErr.message!),
        isNot(contains('6a718e2d-f5bf-420a-af08-95802b1a43b6')),
      );
    });

    test('latches unregistered App Check debug token without repeated retries until manual Retry', () async {
      final provider = _FakeCrmAiDataProvider();
      final transport = _FakeChatTransport()
        ..errorToThrow = FirebaseException(
          plugin: 'firebase_app_check',
          code: 'unknown',
          message: 'Too many attempts.',
        );
      final service = CrmAiAssistantService(
        dataProvider: provider,
        transport: transport,
      );

      // First call hits transport once and latches the App Check error
      await expectLater(
        service.sendMessageStream('Hot leads').toList(),
        throwsA(
          isA<CrmAiAssistantException>().having(
            (e) => e.kind,
            'kind',
            CrmAiErrorKind.appCheck,
          ),
        ),
      );
      expect(transport.sendAttempts, 1);

      // Subsequent non-manual call fails fast without re-hitting transport
      await expectLater(
        service.sendMessageStream('Hot leads').toList(),
        throwsA(isA<CrmAiAssistantException>()),
      );
      expect(transport.sendAttempts, 1);

      // Manual retry after token registration clears latch and succeeds
      transport.errorToThrow = null;
      final chunks = await service
          .sendMessageStream('Hot leads', isManualRetry: true)
          .toList();
      expect(transport.sendAttempts, 2);
      expect(
        chunks.last.accumulatedText,
        contains('0 hot leads'),
      );
    });
  });

  group('AiChatAssistantOverlay widget with grounded Gemini service', () {
    late _FakeCrmAiDataProvider provider;
    late _FakeChatTransport transport;
    late CrmAiAssistantService service;
    ExecutiveLeadItem? openedLead;

    setUp(() {
      provider = _FakeCrmAiDataProvider();
      transport = _FakeChatTransport();
      service = CrmAiAssistantService(
        dataProvider: provider,
        transport: transport,
      );
      openedLead = null;
    });

    Widget buildHarness({Size size = const Size(390, 740)}) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              children: [
                const Center(child: Text('Today screen')),
                AiChatAssistantOverlay(
                  service: service,
                  onOpenLead: (lead) => openedLead = lead,
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets(
      'streams grounded reply, opens referenced CRM record on tap, and closes on Escape',
      (tester) async {
        await tester.pumpWidget(buildHarness());

        await tester.tap(find.bySemanticsLabel('Open AI Assistant'));
        await tester.pumpAndSettle();

        expect(find.text('AI Assistant'), findsOneWidget);
        expect(find.text('Today’s follow-ups'), findsOneWidget);

        // Tap quick reply chip
        await tester.tap(find.text('Today’s follow-ups'));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('Typing...'), findsOneWidget);

        // Wait for stream completion
        await tester.pumpAndSettle();
        expect(find.text('Typing...'), findsNothing);
        expect(
          find.textContaining('You have 1 follow-up due today: Jishnu'),
          findsOneWidget,
        );

        // Tap the record reference pill to open the CRM record (clean name without raw #id)
        final refPill = find.text('Jishnu');
        expect(refPill, findsOneWidget);
        expect(find.textContaining('#lead_101'), findsNothing);
        await tester.tap(refPill);
        await tester.pump();
        expect(openedLead?.id, 'lead_101');

        // Press Escape to close panel
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Open AI Assistant'), findsOneWidget);
      },
    );

    testWidgets(
      'preserves user message on error and succeeds when Retry is tapped',
      (tester) async {
        transport.errorToThrow = QuotaExceeded('Rate limit exceeded');
        await tester.pumpWidget(buildHarness());

        await tester.tap(find.bySemanticsLabel('Open AI Assistant'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Hot leads right now?');
        await tester.tap(find.bySemanticsLabel('Send message'));
        await tester.pumpAndSettle();

        // Shows quota error and preserves the user's message in the TextField
        expect(find.textContaining('Quota exceeded:'), findsOneWidget);
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, 'Hot leads right now?');

        // Clear the simulated error and tap Retry
        transport.errorToThrow = null;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'You currently have 0 hot leads in your permitted CRM records.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('adapts cleanly to narrow small phone without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(size: const Size(320, 520)));
      await tester.tap(find.bySemanticsLabel('Open AI Assistant'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
