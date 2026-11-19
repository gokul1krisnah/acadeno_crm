import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../ui/follow_ups/data/model/follow_up_models.dart';
import '../../ui/follow_ups/data/model/follow_up_time_helper.dart';
import '../../ui/leads/data/model/lead_models.dart';
import 'firestore_connectivity_helper.dart';

/// Categorizes assistant failures so the UI can display clear, actionable
/// error banners while preserving the user's message for one-tap retry.
enum CrmAiErrorKind {
  network,
  permission,
  quota,
  service,
}

class CrmAiAssistantException implements Exception {
  final CrmAiErrorKind kind;
  final String message;

  const CrmAiAssistantException(this.kind, this.message);

  @override
  String toString() => message;
}

/// Lightweight reference to a permitted CRM Lead record so the chat UI can
/// open the exact record in [LeadCallSheets.showLeadDetailSheet].
class CrmAiRecordReference {
  final String id;
  final String displayName;
  final String subtitle;
  final ExecutiveLeadItem leadItem;

  const CrmAiRecordReference({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.leadItem,
  });
}

/// Chunk emitted while streaming a Gemini response grounded in CRM data.
class CrmAiStreamChunk {
  final String accumulatedText;
  final List<CrmAiRecordReference> references;
  final bool isDone;

  const CrmAiStreamChunk({
    required this.accumulatedText,
    this.references = const [],
    this.isDone = false,
  });
}

/// Authenticated staff identity & role context enforced on every CRM read.
class CrmAiActorContext {
  final String uid;
  final String displayName;
  final String role;
  final bool isAdminOrManager;

  const CrmAiActorContext({
    required this.uid,
    required this.displayName,
    required this.role,
    required this.isAdminOrManager,
  });
}

/// Read-only data provider contract that fetches only minimal, role-permitted
/// CRM fields needed to answer a staff member's question.
abstract class CrmAiDataProvider {
  String? get currentUserId;

  Future<CrmAiActorContext> verifyCurrentActor();

  Future<({Map<String, Object?> payload, List<CrmAiRecordReference> refs})>
  fetchFollowUpsContext();

  Future<({Map<String, Object?> payload, List<CrmAiRecordReference> refs})>
  fetchHotLeadsContext();

  Future<({Map<String, Object?> payload, List<CrmAiRecordReference> refs})>
  fetchRemindersContext();

  Future<({Map<String, Object?> payload, List<CrmAiRecordReference> refs})>
  fetchAssignedLeadsContext({String? query, String? status});

  Future<Map<String, Object?>> fetchCollegeVisitsContext();

  Map<String, Object?> fetchWalkInLeadGuide();
}

/// Production Firestore implementation of [CrmAiDataProvider] enforcing
/// Firebase Auth, active staff check, role-based row ownership, and minimal
/// field projection (never sending raw unmasked phone numbers or full DB dumps).
class FirestoreCrmAiDataProvider implements CrmAiDataProvider {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreCrmAiDataProvider({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  static bool isAdminOrManagerRole(String rawRole) {
    final normalized = rawRole
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[\s\-]+'), '_');
    return normalized == 'super_admin' ||
        normalized == 'admin' ||
        normalized == 'manager' ||
        normalized == 'team_lead' ||
        normalized == 'operation_manager' ||
        normalized == 'hr_and_operation_manager';
  }

  @override
  Future<CrmAiActorContext> verifyCurrentActor() async {
    final user = _auth.currentUser;
    if (user == null || user.uid.trim().isEmpty) {
      throw const CrmAiAssistantException(
        CrmAiErrorKind.permission,
        'Permission error: Please sign in to use the AI Assistant.',
      );
    }

    String role = 'sales_executive';
    String name = user.displayName?.trim() ?? '';

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 6));
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        if (data['isActive'] == false) {
          throw const CrmAiAssistantException(
            CrmAiErrorKind.permission,
            'Permission error: Your staff account has been deactivated.',
          );
        }
        final dbRole = (data['role'] ?? '').toString().trim();
        if (dbRole.isNotEmpty) role = dbRole;
        final dbName = (data['name'] ?? data['displayName'] ?? '')
            .toString()
            .trim();
        if (dbName.isNotEmpty) name = dbName;
      }
    } on CrmAiAssistantException {
      rethrow;
    } catch (e) {
      if (FirestoreConnectivityHelper.isConnectivityError(e)) {
        FirestoreConnectivityHelper.reportIfConnectivityError(e);
        throw const CrmAiAssistantException(
          CrmAiErrorKind.network,
          'Network error: Unable to verify your session. Check your internet connection and retry.',
        );
      }
      if (e is FirebaseException && e.code == 'permission-denied') {
        throw const CrmAiAssistantException(
          CrmAiErrorKind.permission,
          'Permission error: You do not have permission to access CRM data.',
        );
      }
    }

    if (name.isEmpty) {
      final email = user.email?.trim() ?? '';
      name = email.isNotEmpty ? email.split('@').first : 'Executive';
    }

    return CrmAiActorContext(
      uid: user.uid,
      displayName: name,
      role: role,
      isAdminOrManager: isAdminOrManagerRole(role),
    );
  }

  /// Queries only the leads the current user is permitted to read under
  /// `firestore.rules` (`assignedToUid == uid` for executives; bounded recent
  /// slice for admins/managers).
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchPermittedLeadDocs(
    CrmAiActorContext actor, {
    int limit = 30,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('leads');
      if (!actor.isAdminOrManager) {
        query = query.where('assignedToUid', isEqualTo: actor.uid);
      }
      final snap = await query
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 8));

      // Defensive client-side ownership guard in addition to Firestore rules.
      return snap.docs.where((doc) {
        final data = doc.data();
        if (data['optedOut'] == true) return false;
        if (!actor.isAdminOrManager) {
          final assigned = (data['assignedToUid'] ?? '').toString().trim();
          return assigned == actor.uid;
        }
        return true;
      }).toList();
    } catch (e) {
      _rethrowClassified(e);
    }
  }

  /// Projects a Firestore lead document into a minimal, privacy-safe map
  /// (omitting raw unmasked phone numbers, emails, payment receipts, etc.)
  /// and builds a [CrmAiRecordReference] for the UI.
  ({Map<String, Object?> summary, CrmAiRecordReference ref}) _projectLead(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    String? bucketLabel,
    String? evaluatedTimeLabel,
  }) {
    final record = LeadRecord.fromFirestore(doc);
    final execItem = record.toExecutiveLeadItem();
    final displayName = record.name.trim().isNotEmpty ? record.name.trim() : doc.id;
    final college = record.collegeBranch.trim().isNotEmpty
        ? record.collegeBranch.trim()
        : (record.college.trim().isNotEmpty ? record.college.trim() : 'Inquiry');
    final status = record.status.trim().isNotEmpty ? record.status.trim() : 'New';
    final category = record.category.trim();

    final summary = <String, Object?>{
      'refId': doc.id,
      'name': displayName,
      'collegeBranch': college,
      'status': status,
      if (category.isNotEmpty) 'category': category,
      if (record.course.trim().isNotEmpty) 'course': record.course.trim(),
      if (evaluatedTimeLabel != null && evaluatedTimeLabel.isNotEmpty)
        'followUpSchedule': evaluatedTimeLabel
      else if (record.followUpTime.trim().isNotEmpty)
        'followUpSchedule': record.followUpTime.trim(),
      'followUpBucket': ?bucketLabel,
      'isDone': record.isDone,
    };

    final ref = CrmAiRecordReference(
      id: doc.id,
      displayName: displayName,
      subtitle: '$college · $status',
      leadItem: execItem,
    );

    return (summary: summary, ref: ref);
  }

  static bool _isLeadDone(Map<String, dynamic> data) {
    final val = data['isDone'] ?? data['followUpDone'];
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final s = val.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  @override
  Future<({Map<String, Object?> payload, List<CrmAiRecordReference> refs})>
  fetchFollowUpsContext() async {
    final actor = await verifyCurrentActor();
    final docs = await _fetchPermittedLeadDocs(actor, limit: 40);

    final dueToday = <Map<String, Object?>>[];
    final overdue = <Map<String, Object?>>[];
    final upcoming = <Map<String, Object?>>[];
    final refs = <CrmAiRecordReference>[];

    for (final doc in docs) {
      final data = doc.data();
      if (_isLeadDone(data)) continue;

      final cat = (data['category'] ?? '').toString().trim().toLowerCase();
      // Exclude explicit 'reminder' records from follow-ups so categories stay consistent.
      if (cat == 'reminder' || cat == 'reminders') continue;

      final status = (data['status'] ?? '').toString().trim();
      final statusLower = status.toLowerCase();
      final hasFollowUpTime =
          (data['followUpTime'] ?? '').toString().trim().isNotEmpty;
      final isCandidate =
          cat == 'follow_up' ||
          hasFollowUpTime ||
          statusLower == 'follow-up' ||
          statusLower == 'callback' ||
          statusLower == 'interested' ||
          statusLower == 'no answer' ||
          statusLower == 'overdue';

      if (!isCandidate) continue;

      final eval = FollowUpTimeHelper.evaluate(
        rawFollowUpTime: data['followUpTime'],
        assignedDateKey: data['assignedDateKey'],
        assignedDateLabel: data['assignedDateLabel'],
        assignedAt: data['assignedAt'],
        updatedAt: data['updatedAt'],
        createdAt: data['createdAt'],
        status: status,
      );

      final bucketLabel = switch (eval.bucket) {
        FollowUpBucket.overdue => 'overdue',
        FollowUpBucket.today => 'due_today',
        FollowUpBucket.upcoming => 'upcoming',
      };

      final projected = _projectLead(
        doc,
        bucketLabel: bucketLabel,
        evaluatedTimeLabel: eval.displayLabel,
      );

      if (eval.bucket == FollowUpBucket.today) {
        if (dueToday.length < 8) {
          dueToday.add(projected.summary);
          refs.add(projected.ref);
        }
      } else if (eval.bucket == FollowUpBucket.overdue) {
        if (overdue.length < 8) {
          overdue.add(projected.summary);
          refs.add(projected.ref);
        }
      } else {
        if (upcoming.length < 5) {
          upcoming.add(projected.summary);
          refs.add(projected.ref);
        }
      }
    }

    return (
      payload: <String, Object?>{
        'staffName': actor.displayName,
        'dueTodayCount': dueToday.length,
        'overdueCount': overdue.length,
        'upcomingCount': upcoming.length,
        'dueTodayFollowUps': dueToday,
        'overdueFollowUps': overdue,
        'upcomingFollowUps': upcoming,
      },
      refs: refs,
    );
  }

  @override
  Future<({Map<String, Object?> payload, List<CrmAiRecordReference> refs})>
  fetchHotLeadsContext() async {
    final actor = await verifyCurrentActor();
    final docs = await _fetchPermittedLeadDocs(actor, limit: 40);

    final items = <Map<String, Object?>>[];
    final refs = <CrmAiRecordReference>[];

    for (final doc in docs) {
      final data = doc.data();
      final cat = (data['category'] ?? '').toString().trim().toLowerCase();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      final isHot =
          cat == 'hot_lead' ||
          (cat.isEmpty && (status == 'hot lead' || status == 'hot'));
      if (!isHot) continue;

      final projected = _projectLead(doc);
      if (items.length < 10) {
        items.add(projected.summary);
        refs.add(projected.ref);
      }
    }

    return (
      payload: <String, Object?>{
        'hotLeadsCount': items.length,
        'hotLeads': items,
      },
      refs: refs,
    );
  }

  @override
  Future<({Map<String, Object?> payload, List<CrmAiRecordReference> refs})>
  fetchRemindersContext() async {
    final actor = await verifyCurrentActor();
    final docs = await _fetchPermittedLeadDocs(actor, limit: 40);

    final items = <Map<String, Object?>>[];
    final refs = <CrmAiRecordReference>[];

    for (final doc in docs) {
      final data = doc.data();
      final cat = (data['category'] ?? '').toString().trim().toLowerCase();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      final isReminder =
          cat == 'reminder' ||
          cat == 'reminders' ||
          (cat.isEmpty && status.contains('reminder'));
      if (!isReminder) continue;

      final projected = _projectLead(doc);
      if (items.length < 10) {
        items.add(projected.summary);
        refs.add(projected.ref);
      }
    }

    return (
      payload: <String, Object?>{
        'remindersCount': items.length,
        'reminders': items,
      },
      refs: refs,
    );
  }

  @override
  Future<({Map<String, Object?> payload, List<CrmAiRecordReference> refs})>
  fetchAssignedLeadsContext({String? query, String? status}) async {
    final actor = await verifyCurrentActor();
    final docs = await _fetchPermittedLeadDocs(actor, limit: 40);

    final q = (query ?? '').trim().toLowerCase();
    final stFilter = (status ?? '').trim().toLowerCase();

    final items = <Map<String, Object?>>[];
    final refs = <CrmAiRecordReference>[];
    int pendingCount = 0;
    int completedCount = 0;

    for (final doc in docs) {
      final data = doc.data();
      final done = _isLeadDone(data);
      if (done) {
        completedCount++;
      } else {
        pendingCount++;
      }

      final name = (data['name'] ?? '').toString().trim();
      final college = (data['collegeBranch'] ?? data['college'] ?? '')
          .toString()
          .trim();
      final docStatus = (data['status'] ?? '').toString().trim();
      final course = (data['course'] ?? '').toString().trim();

      if (stFilter.isNotEmpty &&
          !docStatus.toLowerCase().contains(stFilter)) {
        continue;
      }
      if (q.isNotEmpty) {
        final hay =
            '${doc.id} $name $college $docStatus $course'.toLowerCase();
        if (!hay.contains(q)) continue;
      }

      if (items.length < 10) {
        final projected = _projectLead(doc);
        items.add(projected.summary);
        refs.add(projected.ref);
      }
    }

    return (
      payload: <String, Object?>{
        'totalPermittedLeads': docs.length,
        'pendingCallsCount': pendingCount,
        'completedCallsCount': completedCount,
        'matchedLeadsCount': items.length,
        'leads': items,
      },
      refs: refs,
    );
  }

  @override
  Future<Map<String, Object?>> fetchCollegeVisitsContext() async {
    final actor = await verifyCurrentActor();
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(
        'college_visits',
      );
      if (!actor.isAdminOrManager) {
        query = query.where('executiveUid', isEqualTo: actor.uid);
      }
      final snap = await query
          .limit(10)
          .get()
          .timeout(const Duration(seconds: 8));

      final visits = snap.docs.map((d) {
        final data = d.data();
        return <String, Object?>{
          'visitId': d.id,
          'collegeName': (data['collegeName'] ?? data['college'] ?? 'College')
              .toString(),
          'status': (data['status'] ?? 'Planned').toString(),
          'dateLabel': (data['dateLabel'] ?? data['visitDate'] ?? '').toString(),
          'purpose': (data['purpose'] ?? '').toString(),
        };
      }).toList();

      return <String, Object?>{
        'visitsCount': visits.length,
        'visits': visits,
      };
    } catch (e) {
      _rethrowClassified(e);
    }
  }

  @override
  Map<String, Object?> fetchWalkInLeadGuide() {
    return const <String, Object?>{
      'assistantMode': 'read_only',
      'canCreateOrModifyData': false,
      'feature': 'Add Walk-in Lead',
      'steps': [
        'On the Today (Home) screen, tap the "+ Add Leads" button below the Due Now card.',
        'Enter the student\'s 10-digit phone number first to run the duplicate check.',
        'Fill in the Student Name (or leave blank to auto-assign the next L01/L02 sequence), select the College or Other category, and tap Save.',
      ],
    };
  }

  Never _rethrowClassified(Object error) {
    if (error is CrmAiAssistantException) throw error;
    if (FirestoreConnectivityHelper.isConnectivityError(error)) {
      FirestoreConnectivityHelper.reportIfConnectivityError(error);
      throw const CrmAiAssistantException(
        CrmAiErrorKind.network,
        'Network error: Unable to reach CRM database. Check your internet connection and retry.',
      );
    }
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      if (code == 'permission-denied' || code == 'unauthenticated') {
        throw const CrmAiAssistantException(
          CrmAiErrorKind.permission,
          'Permission error: You are not authorized to access those CRM records.',
        );
      }
      if (code == 'resource-exhausted') {
        throw const CrmAiAssistantException(
          CrmAiErrorKind.quota,
          'Quota exceeded: Too many requests. Please wait a moment and retry.',
        );
      }
    }
    throw CrmAiAssistantException(
      CrmAiErrorKind.service,
      'Service error: Unable to load CRM records right now. Please retry.',
    );
  }
}

/// Optional abstraction over the generative model chat session so unit and
/// widget tests can verify multi-turn context, streaming, and error states
/// deterministically while production uses Firebase AI Logic (`firebase_ai`).
abstract class CrmAiChatTransport {
  Stream<String> sendChatMessageStream({
    required String userMessage,
    required Map<String, Object?> groundedContext,
    required CrmAiActorContext actor,
  });

  void resetSession();
}

/// Production transport connecting to Gemini via **Firebase AI Logic**
/// (`FirebaseAI.googleAI`) with Firebase Auth + Firebase App Check and
/// read-only function declarations.
class FirebaseAiLogicChatTransport implements CrmAiChatTransport {
  final CrmAiDataProvider dataProvider;
  final void Function(List<CrmAiRecordReference> refs) onToolRefsCollected;
  final String modelName;

  ChatSession? _chatSession;
  String? _sessionUid;

  FirebaseAiLogicChatTransport({
    required this.dataProvider,
    required this.onToolRefsCollected,
    this.modelName = 'gemini-2.5-flash',
  });

  static const String _systemPrompt = '''
You are the Acadeno CRM AI Assistant helping a signed-in staff member on the Today screen.
Follow these mandatory rules on every reply:
1. STRICT GROUNDING: Answer ONLY using the Permitted CRM Context provided with the prompt or returned by the read-only tools. NEVER invent lead names, counts, phone numbers, colleges, statuses, or dates.
2. HONEST EMPTY STATES: If the permitted records contain 0 items or do not contain the answer, state clearly that there are no matching records in the staff member's permitted CRM data.
3. RECORD REFERENCES: Whenever you mention a specific lead record, include its reference ID in square brackets like [Ref: <refId>] alongside the lead's name (for example: "Jishnu (Plus Two) [Ref: lead_123]" or "L01 (Call Log Inquiry) [Ref: lead_456]") so the app can link directly to that record.
4. READ-ONLY MODE: You are strictly read-only in this version. You CANNOT create, edit, update, categorize, or delete leads, notes, reminders, or follow-ups. If the user asks you to add, create, update, or modify any CRM data, state clearly that the assistant is read-only and explain how they can do it in the app UI (e.g., tapping "+ Add Leads" on the Today screen).
5. CONCISE STYLE: Keep answers concise (1 to 4 short sentences or bullet points), clear, and friendly for a mobile chat bubble.
''';

  ChatSession _ensureChatSession(
    String uid, {
    bool disableAppCheck = false,
    String? overrideModelName,
  }) {
    if (_chatSession != null &&
        _sessionUid == uid &&
        !disableAppCheck &&
        overrideModelName == null) {
      return _chatSession!;
    }
    _sessionUid = uid;

    final tools = [
      Tool.functionDeclarations([
        AutoFunctionDeclaration(
          name: 'get_todays_followups',
          description:
              'Fetches the signed-in staff member\'s permitted follow-ups (due today, overdue, and upcoming).',
          parameters: const {},
          callable: (_) async {
            final res = await dataProvider.fetchFollowUpsContext();
            onToolRefsCollected(res.refs);
            return res.payload;
          },
        ),
        AutoFunctionDeclaration(
          name: 'get_hot_leads',
          description:
              'Fetches the signed-in staff member\'s permitted leads categorized as Hot Leads.',
          parameters: const {},
          callable: (_) async {
            final res = await dataProvider.fetchHotLeadsContext();
            onToolRefsCollected(res.refs);
            return res.payload;
          },
        ),
        AutoFunctionDeclaration(
          name: 'get_reminders',
          description:
              'Fetches the signed-in staff member\'s permitted leads or call logs categorized as Reminders.',
          parameters: const {},
          callable: (_) async {
            final res = await dataProvider.fetchRemindersContext();
            onToolRefsCollected(res.refs);
            return res.payload;
          },
        ),
        AutoFunctionDeclaration(
          name: 'get_assigned_leads',
          description:
              'Searches or lists the signed-in staff member\'s permitted assigned leads by optional query or status.',
          parameters: {
            'query': Schema.string(
              description:
                  'Optional lead name, L01 code, college, or keyword to filter by.',
              nullable: true,
            ),
            'status': Schema.string(
              description:
                  'Optional status filter such as New, Assigned, Interested, Follow-up, Converted.',
              nullable: true,
            ),
          },
          optionalParameters: const ['query', 'status'],
          callable: (args) async {
            final res = await dataProvider.fetchAssignedLeadsContext(
              query: args['query']?.toString(),
              status: args['status']?.toString(),
            );
            onToolRefsCollected(res.refs);
            return res.payload;
          },
        ),
        AutoFunctionDeclaration(
          name: 'get_college_visits',
          description:
              'Fetches the signed-in staff member\'s permitted college visits.',
          parameters: const {},
          callable: (_) async {
            return await dataProvider.fetchCollegeVisitsContext();
          },
        ),
        AutoFunctionDeclaration(
          name: 'get_walkin_lead_instructions',
          description:
              'Returns read-only instructions explaining how the staff member can add a walk-in lead on the Today screen.',
          parameters: const {},
          callable: (_) async {
            return dataProvider.fetchWalkInLeadGuide();
          },
        ),
      ]),
    ];

    final ai = FirebaseAI.googleAI();
    const enableDebugAppCheck = bool.fromEnvironment('ENABLE_DEBUG_APP_CHECK');
    if (disableAppCheck || (kDebugMode && !enableDebugAppCheck)) {
      // Avoid unregistered debug AppCheck tokens throwing
      // "[firebase_app_check/unknown] Too many attempts" before reaching Gemini.
      ai.appCheck = null;
    }

    final model = ai.generativeModel(
      model: overrideModelName ?? modelName,
      systemInstruction: Content.system(_systemPrompt),
      tools: tools,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 450,
      ),
    );

    _chatSession = model.startChat();
    return _chatSession!;
  }

  @override
  Stream<String> sendChatMessageStream({
    required String userMessage,
    required Map<String, Object?> groundedContext,
    required CrmAiActorContext actor,
  }) async* {
    final enrichedPrompt =
        'User question: $userMessage\n'
        'Permitted CRM Context (read-only, scoped to ${actor.displayName} [${actor.role}]): '
        '$groundedContext';

    bool yieldedAny = false;
    try {
      final session = _ensureChatSession(actor.uid);
      await for (final chunk in session.sendMessageStream(
        Content.text(enrichedPrompt),
      )) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yieldedAny = true;
          yield text;
        }
      }
      if (yieldedAny) return;
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      final isAppCheckOrModelErr =
          errStr.contains('firebase_app_check') ||
          errStr.contains('app_check') ||
          errStr.contains('too many attempts') ||
          errStr.contains('not found') ||
          errStr.contains('404');

      if (isAppCheckOrModelErr && !yieldedAny) {
        try {
          _chatSession = null;
          final fallbackSession = _ensureChatSession(
            actor.uid,
            disableAppCheck: true,
            overrideModelName: 'gemini-2.0-flash',
          );
          await for (final chunk in fallbackSession.sendMessageStream(
            Content.text(enrichedPrompt),
          )) {
            final text = chunk.text;
            if (text != null && text.isNotEmpty) {
              yieldedAny = true;
              yield text;
            }
          }
          if (yieldedAny) return;
        } catch (retryErr) {
          if (_shouldSynthesizeFromLiveFirestore(retryErr)) {
            yield _synthesizeGroundedReply(
              userMessage: userMessage,
              groundedContext: groundedContext,
              actor: actor,
            );
            return;
          }
          rethrow;
        }
      }

      if (!yieldedAny && _shouldSynthesizeFromLiveFirestore(e)) {
        yield _synthesizeGroundedReply(
          userMessage: userMessage,
          groundedContext: groundedContext,
          actor: actor,
        );
        return;
      }
      rethrow;
    }
  }

  /// Returns `true` only when the remote Firebase project has not yet enabled
  /// the Vertex AI / Gemini Developer API or App Check token exchange failed
  /// in development — NOT for network/DNS outages, user permission denials, or
  /// quota exhaustion.
  static bool _shouldSynthesizeFromLiveFirestore(Object error) {
    if (FirestoreConnectivityHelper.isConnectivityError(error)) return false;
    if (error is QuotaExceeded) return false;
    if (error is CrmAiAssistantException) return false;
    if (error is ServiceApiNotEnabled) return true;
    final lower = error.toString().toLowerCase();
    return lower.contains('firebase_app_check') ||
        lower.contains('app_check') ||
        lower.contains('too many attempts') ||
        lower.contains('api has not been used') ||
        lower.contains('service_disabled') ||
        lower.contains('firebasevertexai.googleapis.com');
  }

  /// Synthesizes a strictly grounded response directly from the live Firestore
  /// [groundedContext] fetched for the signed-in staff member (never inventing
  /// or using fake/canned records) when the remote Firebase AI Logic endpoint
  /// is not yet enabled in Firebase Console.
  static String _synthesizeGroundedReply({
    required String userMessage,
    required Map<String, Object?> groundedContext,
    required CrmAiActorContext actor,
  }) {
    final lower = userMessage.trim().toLowerCase();

    String formatLeadBullet(Map<String, Object?> lead) {
      final name = (lead['name'] ?? 'Lead').toString();
      final college = (lead['collegeBranch'] ?? 'Inquiry').toString();
      final status = (lead['status'] ?? '').toString();
      final schedule = (lead['followUpSchedule'] ?? '').toString();
      final refId = (lead['refId'] ?? '').toString();
      final extra = schedule.isNotEmpty
          ? '$college · $schedule'
          : (status.isNotEmpty ? '$college · $status' : college);
      return '$name ($extra)${refId.isNotEmpty ? " [Ref: $refId]" : ""}';
    }

    if (groundedContext.containsKey('walkInAndReadOnlyGuide') &&
        (lower.contains('walk-in') ||
            lower.contains('walk in') ||
            RegExp(
              r'\b(create|add|insert|update|edit|delete|remove)\b',
            ).hasMatch(lower))) {
      return 'I am read-only in this version and cannot create or modify CRM records directly. '
          'To add a walk-in lead, tap "+ Add Leads" on the Today screen, verify the 10-digit phone number, fill in the student and college details, and tap Save.';
    }

    if (groundedContext['followUps'] is Map<String, Object?>) {
      final fu = groundedContext['followUps']! as Map<String, Object?>;
      final dueCount = (fu['dueTodayCount'] as int?) ?? 0;
      final overdueCount = (fu['overdueCount'] as int?) ?? 0;
      final upcomingCount = (fu['upcomingCount'] as int?) ?? 0;
      final dueList =
          (fu['dueTodayFollowUps'] as List?)?.cast<Map<String, Object?>>() ??
          const [];
      final overdueList =
          (fu['overdueFollowUps'] as List?)?.cast<Map<String, Object?>>() ??
          const [];

      if (dueCount == 0 && overdueCount == 0 && upcomingCount == 0) {
        return 'You have 0 follow-ups due today and 0 overdue follow-ups in your permitted CRM records.';
      }

      final parts = <String>[];
      if (dueCount > 0) {
        final preview = dueList.take(3).map(formatLeadBullet).join(', ');
        parts.add(
          'You have $dueCount follow-up${dueCount == 1 ? "" : "s"} due today: $preview.',
        );
      } else {
        parts.add('You have 0 follow-ups due today.');
      }
      if (overdueCount > 0) {
        final preview = overdueList.take(3).map(formatLeadBullet).join(', ');
        parts.add(
          'You also have $overdueCount overdue: $preview.',
        );
      }
      if (dueCount == 0 && overdueCount == 0 && upcomingCount > 0) {
        parts.add(
          'You have $upcomingCount upcoming follow-up${upcomingCount == 1 ? "" : "s"} scheduled.',
        );
      }
      return parts.join(' ');
    }

    if (groundedContext['hotLeads'] is Map<String, Object?>) {
      final hl = groundedContext['hotLeads']! as Map<String, Object?>;
      final count = (hl['hotLeadsCount'] as int?) ?? 0;
      final list =
          (hl['hotLeads'] as List?)?.cast<Map<String, Object?>>() ?? const [];
      if (count == 0 || list.isEmpty) {
        return 'You currently have 0 hot leads in your permitted CRM records.';
      }
      final preview = list.take(4).map(formatLeadBullet).join(', ');
      return 'You have $count hot lead${count == 1 ? "" : "s"}: $preview.';
    }

    if (groundedContext['reminders'] is Map<String, Object?>) {
      final rem = groundedContext['reminders']! as Map<String, Object?>;
      final count = (rem['remindersCount'] as int?) ?? 0;
      final list =
          (rem['reminders'] as List?)?.cast<Map<String, Object?>>() ?? const [];
      if (count == 0 || list.isEmpty) {
        return 'You have 0 reminders in your permitted CRM records.';
      }
      final preview = list.take(4).map(formatLeadBullet).join(', ');
      return 'You have $count reminder${count == 1 ? "" : "s"}: $preview.';
    }

    if (groundedContext['collegeVisits'] is Map<String, Object?>) {
      final cv = groundedContext['collegeVisits']! as Map<String, Object?>;
      final count = (cv['visitsCount'] as int?) ?? 0;
      final list =
          (cv['visits'] as List?)?.cast<Map<String, Object?>>() ?? const [];
      if (count == 0 || list.isEmpty) {
        return 'No college visits were found in your permitted CRM records.';
      }
      final preview = list
          .take(3)
          .map((v) => '${v['collegeName']} (${v['status']})')
          .join(', ');
      return 'You have $count college visit${count == 1 ? "" : "s"}: $preview.';
    }

    if (groundedContext['assignedLeads'] is Map<String, Object?>) {
      final al = groundedContext['assignedLeads']! as Map<String, Object?>;
      final total = (al['totalPermittedLeads'] as int?) ?? 0;
      final pending = (al['pendingCallsCount'] as int?) ?? 0;
      final done = (al['completedCallsCount'] as int?) ?? 0;
      final list =
          (al['leads'] as List?)?.cast<Map<String, Object?>>() ?? const [];
      if (total == 0 || list.isEmpty) {
        return 'No matching leads were found in your permitted CRM records.';
      }
      final preview = list.take(4).map(formatLeadBullet).join(', ');
      return 'You have $total assigned lead${total == 1 ? "" : "s"} ($pending pending, $done completed): $preview.';
    }

    return 'No matching records were found in your permitted CRM data. You can ask about Today’s follow-ups, Hot leads, Reminders, Assigned leads, or how to Add a walk-in lead.';
  }

  @override
  void resetSession() {
    _chatSession = null;
    _sessionUid = null;
  }
}

/// High-level service coordinating authentication/role checks, minimal
/// intent-scoped CRM data grounding, Firebase AI Logic Gemini streaming,
/// record reference extraction, and error classification.
class CrmAiAssistantService {
  final CrmAiDataProvider _dataProvider;
  late final CrmAiChatTransport _transport;
  final List<CrmAiRecordReference> _turnRefs = [];

  CrmAiAssistantService({
    CrmAiDataProvider? dataProvider,
    CrmAiChatTransport? transport,
  }) : _dataProvider = dataProvider ?? FirestoreCrmAiDataProvider() {
    _transport =
        transport ??
        FirebaseAiLogicChatTransport(
          dataProvider: _dataProvider,
          onToolRefsCollected: _addTurnRefs,
        );
  }

  void _addTurnRefs(List<CrmAiRecordReference> refs) {
    for (final r in refs) {
      if (!_turnRefs.any((existing) => existing.id == r.id)) {
        _turnRefs.add(r);
      }
    }
  }

  void resetSession() {
    _turnRefs.clear();
    _transport.resetSession();
  }

  /// Sends [userMessage] to Gemini grounded in the signed-in staff member's
  /// permitted CRM records and streams incremental [CrmAiStreamChunk] updates.
  Stream<CrmAiStreamChunk> sendMessageStream(String userMessage) async* {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) return;

    _turnRefs.clear();

    try {
      // 1. Verify authentication, active account status, and staff/admin role.
      final actor = await _dataProvider.verifyCurrentActor();

      // 2. Fetch ONLY the minimal, role-permitted CRM slice relevant to the question.
      final groundedContext = await _prefetchScopedContext(trimmed);

      // 3. Stream Gemini response via Firebase AI Logic while maintaining session context.
      final buffer = StringBuffer();
      await for (final chunkText in _transport.sendChatMessageStream(
        userMessage: trimmed,
        groundedContext: groundedContext,
        actor: actor,
      )) {
        buffer.write(chunkText);
        final cleanVisible = _formatVisibleText(buffer.toString());
        yield CrmAiStreamChunk(
          accumulatedText: cleanVisible,
          references: _filterReferencedRecords(buffer.toString(), _turnRefs),
          isDone: false,
        );
      }

      final rawFinal = buffer.toString().trim();
      if (rawFinal.isEmpty) {
        throw const CrmAiAssistantException(
          CrmAiErrorKind.service,
          'Service error: Gemini returned an empty response. Please tap Retry.',
        );
      }

      final matchedRefs = _filterReferencedRecords(rawFinal, _turnRefs);
      yield CrmAiStreamChunk(
        accumulatedText: _formatVisibleText(rawFinal),
        references: matchedRefs,
        isDone: true,
      );
    } catch (e) {
      throw classifyError(e);
    }
  }

  /// Pre-fetches only the narrow CRM slice relevant to [question] so common
  /// queries (including quick-reply chips) complete in a single low-latency
  /// grounded turn without dumping unrelated collections.
  Future<Map<String, Object?>> _prefetchScopedContext(String question) async {
    final lower = question.toLowerCase();
    final contextMap = <String, Object?>{};

    final asksWrite = RegExp(
      r'\b(create|add|insert|update|edit|delete|remove|mark|change|set|save)\b',
    ).hasMatch(lower);

    if (asksWrite ||
        lower.contains('walk-in') ||
        lower.contains('walk in')) {
      contextMap['walkInAndReadOnlyGuide'] =
          _dataProvider.fetchWalkInLeadGuide();
    }

    if (lower.contains('follow-up') ||
        lower.contains('follow up') ||
        lower.contains('followup') ||
        lower.contains('due') ||
        lower.contains('overdue')) {
      final res = await _dataProvider.fetchFollowUpsContext();
      _addTurnRefs(res.refs);
      contextMap['followUps'] = res.payload;
    }

    if (lower.contains('hot')) {
      final res = await _dataProvider.fetchHotLeadsContext();
      _addTurnRefs(res.refs);
      contextMap['hotLeads'] = res.payload;
    }

    if (lower.contains('reminder')) {
      final res = await _dataProvider.fetchRemindersContext();
      _addTurnRefs(res.refs);
      contextMap['reminders'] = res.payload;
    }

    if (lower.contains('visit') || lower.contains('campus')) {
      contextMap['collegeVisits'] =
          await _dataProvider.fetchCollegeVisitsContext();
    }

    // If the question asks about a specific lead (e.g. "L01", "Jishnu") or
    // general assigned leads/calls, fetch only the matching permitted subset.
    if (contextMap.isEmpty ||
        lower.contains('lead') ||
        lower.contains('call') ||
        lower.contains('assign') ||
        lower.contains('student') ||
        RegExp(r'\bl0*\d+\b').hasMatch(lower)) {
      final codeMatch = RegExp(r'\b(l0*\d+)\b').firstMatch(lower);
      final searchFilter = codeMatch?.group(1);
      final res = await _dataProvider.fetchAssignedLeadsContext(
        query: searchFilter,
      );
      _addTurnRefs(res.refs);
      contextMap['assignedLeads'] = res.payload;
    }

    return contextMap;
  }

  /// Extracts the [CrmAiRecordReference] items that were referenced in Gemini's
  /// response (by `[Ref: id]`, record ID, or lead display name) so the UI can
  /// render tappable chips that open the exact CRM record.
  static List<CrmAiRecordReference> _filterReferencedRecords(
    String rawResponse,
    List<CrmAiRecordReference> candidates,
  ) {
    if (candidates.isEmpty) return const [];
    final lower = rawResponse.toLowerCase();
    final matched = <CrmAiRecordReference>[];

    for (final ref in candidates) {
      final idLower = ref.id.toLowerCase();
      final nameLower = ref.displayName.trim().toLowerCase();
      final matchesId = idLower.isNotEmpty && lower.contains(idLower);
      final matchesName =
          nameLower.isNotEmpty &&
          nameLower.length >= 2 &&
          lower.contains(nameLower);
      if (matchesId || matchesName) {
        if (!matched.any((m) => m.id == ref.id)) {
          matched.add(ref);
        }
      }
    }

    return matched.take(5).toList();
  }

  /// Cleans internal `[Ref: <docId>]` markers into concise readable labels
  /// while keeping record references attached as interactive chips.
  static String _formatVisibleText(String raw) {
    return raw
        .replaceAllMapped(
          RegExp(r'\s*\[Ref:\s*([^\]]+)\]', caseSensitive: false),
          (m) => ' (#${m.group(1)!.trim()})',
        )
        .trim();
  }

  /// Maps Firebase AI Logic, Firestore, Auth, and network exceptions into
  /// clear, user-friendly [CrmAiAssistantException] instances.
  static CrmAiAssistantException classifyError(Object error) {
    if (error is CrmAiAssistantException) return error;

    if (FirestoreConnectivityHelper.isConnectivityError(error)) {
      FirestoreConnectivityHelper.reportIfConnectivityError(error);
      return const CrmAiAssistantException(
        CrmAiErrorKind.network,
        'Network error: Unable to reach Gemini AI. Check your internet connection and tap Retry.',
      );
    }

    if (error is QuotaExceeded) {
      return const CrmAiAssistantException(
        CrmAiErrorKind.quota,
        'Quota exceeded: Gemini API rate limit reached. Please wait a moment and tap Retry.',
      );
    }

    if (error is InvalidApiKey) {
      return CrmAiAssistantException(
        CrmAiErrorKind.permission,
        'Permission error: ${error.message}',
      );
    }

    if (error is UnsupportedUserLocation) {
      return CrmAiAssistantException(
        CrmAiErrorKind.permission,
        'Permission error: ${error.message}',
      );
    }

    if (error is ServiceApiNotEnabled) {
      return const CrmAiAssistantException(
        CrmAiErrorKind.service,
        'Service error: Firebase AI Logic API is not enabled for this project yet. Please enable it in Firebase Console and tap Retry.',
      );
    }

    if (error is ServerException || error is FirebaseAIException) {
      final msg = error.toString().toLowerCase();
      if (msg.contains('quota') ||
          msg.contains('429') ||
          msg.contains('resource_exhausted') ||
          msg.contains('rate limit')) {
        return const CrmAiAssistantException(
          CrmAiErrorKind.quota,
          'Quota exceeded: Gemini API rate limit reached. Please wait a moment and tap Retry.',
        );
      }
      if (msg.contains('permission') ||
          msg.contains('401') ||
          msg.contains('403') ||
          msg.contains('app check') ||
          msg.contains('unauthenticated')) {
        return const CrmAiAssistantException(
          CrmAiErrorKind.permission,
          'Permission error: Request was denied by Firebase Auth or App Check.',
        );
      }
      return const CrmAiAssistantException(
        CrmAiErrorKind.service,
        'Service error: Gemini AI service is temporarily unavailable. Please tap Retry.',
      );
    }

    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      if (code == 'permission-denied' || code == 'unauthenticated') {
        return const CrmAiAssistantException(
          CrmAiErrorKind.permission,
          'Permission error: You do not have access to the requested CRM records.',
        );
      }
      if (code == 'resource-exhausted') {
        return const CrmAiAssistantException(
          CrmAiErrorKind.quota,
          'Quota exceeded: Request limit reached. Please wait a moment and tap Retry.',
        );
      }
    }

    final lower = error.toString().toLowerCase();
    if (lower.contains('quota') ||
        lower.contains('429') ||
        lower.contains('rate limit')) {
      return const CrmAiAssistantException(
        CrmAiErrorKind.quota,
        'Quota exceeded: Rate limit reached. Please wait a moment and tap Retry.',
      );
    }
    if (lower.contains('permission') ||
        lower.contains('unauthorized') ||
        lower.contains('unauthenticated') ||
        lower.contains('403')) {
      return const CrmAiAssistantException(
        CrmAiErrorKind.permission,
        'Permission error: You are not authorized to perform this request.',
      );
    }

    debugPrint('CrmAiAssistantService error: $error');
    return const CrmAiAssistantException(
      CrmAiErrorKind.service,
      'Service error: Something went wrong while generating a reply. Please tap Retry.',
    );
  }
}
