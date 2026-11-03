import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Phone number normalization, validation, and masking utilities (FR-1.2, PR-2.3).
abstract final class LeadPhoneValidator {
  /// Extracts the canonical 10-digit mobile number from [raw].
  /// Returns `''` if the input does not contain a valid 10-digit number.
  static String normalize10Digits(String? raw) {
    if (raw == null) return '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return digits;
    if (digits.length == 11 && digits.startsWith('0')) {
      return digits.substring(1);
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    return '';
  }

  /// Validates a phone string and returns an error message or `null` if valid.
  static String? validate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Phone number is required';
    }
    final normalized = normalize10Digits(raw);
    if (normalized.length != 10) {
      return 'Enter a valid 10-digit phone number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(normalized)) {
      return 'Enter a valid 10-digit mobile number starting with 6–9';
    }
    return null;
  }

  /// Formats a 10-digit phone as `'98470 33333'`.
  static String formatDisplayPhone(String raw) {
    final norm = normalize10Digits(raw);
    if (norm.length == 10) {
      return '${norm.substring(0, 5)} ${norm.substring(5)}';
    }
    final trimmed = raw.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }

  /// Formats a 10-digit phone as `'98470 •••33'` for Sales Executive privacy (PR-2.3).
  static String maskPhone(String raw) {
    final norm = normalize10Digits(raw);
    if (norm.length == 10) {
      return '${norm.substring(0, 5)} •••${norm.substring(8)}';
    }
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 7) {
      return '${digits.substring(0, 5)} •••${digits.substring(digits.length - 2)}';
    }
    return '98470 •••00';
  }

  /// Computes 1–2 uppercase initials from a student or executive name.
  static String initialsFromName(String name, {String fallback = 'LD'}) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2);
    final res = parts.map((p) => p[0].toUpperCase()).join();
    return res.isEmpty ? fallback : res;
  }
}

/// Date key (`YYYY-MM-DD`) and display label helpers for daily assignments.
abstract final class LeadDateHelper {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Canonical ISO date key (`YYYY-MM-DD`) in local time.
  static String dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String todayDateKey([DateTime? now]) => dateKey(now ?? DateTime.now());

  /// Human-readable label such as `'Today, 29 Oct'`, `'Tomorrow, 30 Oct'`, or `'Sat, 31 Oct'`.
  static String dateLabel(DateTime date, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    final dayMonth = '${target.day} ${_months[target.month - 1]}';
    if (diff == 0) return 'Today, $dayMonth';
    if (diff == 1) return 'Tomorrow, $dayMonth';
    return '${_days[target.weekday - 1]}, $dayMonth';
  }

  /// Returns `(dateKey, dateLabel)` options for Today, Tomorrow, and +2 days.
  static List<({String dateKey, String label})> upcomingAssignmentDates([
    DateTime? now,
  ]) {
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    return List.generate(3, (i) {
      final d = today.add(Duration(days: i));
      return (dateKey: dateKey(d), label: dateLabel(d, now: today));
    });
  }

  static String formatTimestamp(dynamic ts, {String fallback = '—'}) {
    DateTime? dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else if (ts is DateTime) {
      dt = ts;
    } else if (ts is String && ts.trim().isNotEmpty) {
      return ts.trim();
    }
    if (dt == null) return fallback;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day} ${_months[dt.month - 1]}';
  }

  /// Evaluates and formats the actual Last Contact for a lead based on real call logs,
  /// timestamps, and status (returns 'Never' if uncontacted).
  static String formatLastContact({
    dynamic lastContactAt,
    dynamic lastCalledAt,
    dynamic rawLastContact,
    dynamic updatedAt,
    dynamic createdAt,
    String status = '',
    List<dynamic>? timeline,
  }) {
    DateTime? dt;
    final primaryTs = lastContactAt ?? lastCalledAt;
    if (primaryTs is Timestamp) {
      dt = primaryTs.toDate();
    } else if (primaryTs is DateTime) {
      dt = primaryTs;
    } else if (primaryTs is String && primaryTs.trim().isNotEmpty) {
      try {
        dt = DateTime.parse(primaryTs.trim());
      } catch (_) {}
    }

    final s = status.trim().toLowerCase();
    final isUncontactedStatus = s == 'new' || s == 'unassigned' || s.isEmpty;

    if (dt == null) {
      if (isUncontactedStatus) {
        return 'Never';
      }

      if (timeline != null && timeline.isNotEmpty) {
        for (final entry in timeline) {
          final str = entry.toString().toLowerCase();
          if (str.contains('logged by') ||
              str.contains('call') ||
              str.contains('contacted')) {
            final uTs = updatedAt ?? createdAt;
            if (uTs is Timestamp) {
              dt = uTs.toDate();
              break;
            } else if (uTs is DateTime) {
              dt = uTs;
              break;
            }
          }
        }
      }

      if (dt == null) {
        final raw = (rawLastContact ?? '').toString().trim();
        final rawLower = raw.toLowerCase();
        if (rawLower == 'just now' || rawLower == 'recently') {
          return isUncontactedStatus ? 'Never' : 'Today';
        }
        if (rawLower == 'never' || raw == '—' || raw.isEmpty) {
          return 'Never';
        }
        if (rawLower == 'today') {
          final uTs = updatedAt;
          if (uTs is Timestamp) {
            final uDt = uTs.toDate();
            final now = DateTime.now();
            final diff = DateTime(
              now.year,
              now.month,
              now.day,
            ).difference(DateTime(uDt.year, uDt.month, uDt.day)).inDays;
            if (diff == 0) return 'Today';
            if (diff == 1) return 'Yesterday';
            if (diff > 1 && diff < 7) return _days[uDt.weekday - 1];
            return '${uDt.day} ${_months[uDt.month - 1]}';
          }
          return isUncontactedStatus ? 'Never' : 'Today';
        }
        return raw;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) {
      return 'Today';
    }
    if (diff == 1) {
      return 'Yesterday';
    }
    if (diff > 1 && diff < 7) {
      return _days[dt.weekday - 1];
    }
    return '${dt.day} ${_months[dt.month - 1]}';
  }
}

/// Thrown when a lead with the same normalized 10-digit phone already exists.
class DuplicateLeadException implements Exception {
  final String phone10;
  final String existingLeadId;
  final String existingLeadName;
  final String existingOwnerName;

  const DuplicateLeadException({
    required this.phone10,
    required this.existingLeadId,
    required this.existingLeadName,
    required this.existingOwnerName,
  });

  @override
  String toString() {
    final ownerSuffix = existingOwnerName.isNotEmpty && existingOwnerName != '—'
        ? ', owned by $existingOwnerName'
        : '';
    return 'Lead with phone $phone10 already exists ($existingLeadName$ownerSuffix).';
  }
}

/// Thrown when an assignment conflicts or violates business rules.
class AssignmentConflictException implements Exception {
  final String message;

  const AssignmentConflictException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the current user lacks permission to access or modify records.
class LeadPermissionException implements Exception {
  final String message;

  const LeadPermissionException(this.message);

  @override
  String toString() => message;
}

/// Firestore model for a document in the `leads` collection.
class LeadRecord {
  final String id;
  final String name;
  final String phone;
  final String phoneNormalized;
  final String email;
  final String course;
  final String fee;
  final String consent;
  final String collegeBranch;
  final String college;
  final String branch;
  final String year;
  final String source;
  final String status;
  final String lastContact;
  final String? assignedToUid;
  final String assignedToName;
  final String? assignedDateKey;
  final String? assignedDateLabel;
  final String? assignedByUid;
  final String? assignedByName;
  final DateTime? assignedAt;
  final String notes;
  final bool isDone;
  final bool isLocked;
  final String? lockedByUid;
  final String? lockedMessage;
  final List<String> talkingPoints;
  final List<String> timeline;
  final String? createdByUid;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LeadRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.phoneNormalized,
    this.email = '',
    this.course = '',
    this.fee = '',
    this.consent = '',
    required this.collegeBranch,
    this.college = '',
    this.branch = '',
    this.year = '',
    required this.source,
    required this.status,
    this.lastContact = '—',
    this.assignedToUid,
    this.assignedToName = '—',
    this.assignedDateKey,
    this.assignedDateLabel,
    this.assignedByUid,
    this.assignedByName,
    this.assignedAt,
    this.notes = '',
    this.isDone = false,
    this.isLocked = false,
    this.lockedByUid,
    this.lockedMessage,
    this.talkingPoints = const [
      '2-day hands-on AI & Python certificate workshop (14–15 Nov)',
      'Standard fee ₹1,499 · Early-bird / group of 3+ ₹999 (Discounts > ₹500 require Manager approval)',
      'Includes internship eligibility test & project certificate from Acadeno Research & Innovation Centre',
    ],
    this.timeline = const [],
    this.createdByUid,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  String get maskedPhone => LeadPhoneValidator.maskPhone(
    phoneNormalized.isNotEmpty ? phoneNormalized : phone,
  );

  String get initials => LeadPhoneValidator.initialsFromName(name);

  bool get isAssigned =>
      assignedToUid != null &&
      assignedToUid!.trim().isNotEmpty &&
      assignedToName != '—';

  /// Parses `"NIT Calicut · CSE · 3rd yr"` into `(college, branch, year)`.
  static ({String college, String branch, String year}) parseCollegeBranch(
    String raw,
  ) {
    final parts = raw
        .split(RegExp(r'\s*[·•|-]\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return (
      college: parts.isNotEmpty ? parts[0] : '',
      branch: parts.length > 1 ? parts[1] : '',
      year: parts.length > 2 ? parts[2] : '',
    );
  }

  factory LeadRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return LeadRecord.fromMap(doc.id, doc.data() ?? const {});
  }

  factory LeadRecord.fromMap(String id, Map<String, dynamic> data) {
    final rawName =
        (data['name'] ?? data['studentName'] ?? data['fullName'] ?? 'Unnamed')
            .toString()
            .trim();
    final rawPhone =
        (data['phone'] ??
                data['phoneNumber'] ??
                data['mobile'] ??
                data['phoneNormalized'] ??
                '')
            .toString()
            .trim();
    final normPhone =
        (data['phoneNormalized'] != null &&
            data['phoneNormalized'].toString().trim().length == 10)
        ? data['phoneNormalized'].toString().trim()
        : LeadPhoneValidator.normalize10Digits(rawPhone);

    String collegeBranch = (data['collegeBranch'] ?? data['collegeInfo'] ?? '')
        .toString()
        .trim();
    String college = (data['college'] ?? '').toString().trim();
    String branch = (data['branch'] ?? '').toString().trim();
    String year = (data['year'] ?? '').toString().trim();

    if (collegeBranch.isEmpty) {
      final parts = [
        if (college.isNotEmpty) college,
        if (branch.isNotEmpty) branch,
        if (year.isNotEmpty) year,
      ];
      collegeBranch = parts.isEmpty ? '—' : parts.join(' · ');
    } else if (college.isEmpty && branch.isEmpty) {
      final parsed = parseCollegeBranch(collegeBranch);
      college = parsed.college;
      branch = parsed.branch;
      year = parsed.year;
    }

    final source =
        (data['source'] ??
                data['campaign'] ??
                data['campaignTag'] ??
                'Direct visit')
            .toString()
            .trim();
    final status = (data['status'] ?? data['statusTag'] ?? 'New')
        .toString()
        .trim();

    final assignedUidRaw =
        (data['assignedToUid'] ??
                data['executiveUid'] ??
                data['assignedExecutiveId'] ??
                '')
            .toString()
            .trim();
    final assignedNameRaw =
        (data['assignedToName'] ??
                data['assignedTo'] ??
                data['executiveName'] ??
                '')
            .toString()
            .trim();

    final createdAtField = data['createdAt'];
    final updatedAtField = data['updatedAt'];
    final assignedAtField = data['assignedAt'];
    final lastContactField = data['lastContact'] ?? data['lastContactAt'];

    final rawTimeline = data['timeline'];
    final timelineList = rawTimeline is Iterable
        ? rawTimeline.map((e) => e.toString()).toList()
        : <String>[
            if (assignedNameRaw.isNotEmpty && assignedNameRaw != '—')
              'Assigned to $assignedNameRaw${data['assignedByName'] != null ? " by ${data['assignedByName']}" : ""}',
            'Registered via $source (Consent recorded)',
          ];

    final rawTalkingPoints = data['talkingPoints'];
    final talkingPointsList =
        rawTalkingPoints is Iterable && rawTalkingPoints.isNotEmpty
        ? rawTalkingPoints.map((e) => e.toString()).toList()
        : const <String>[
            '2-day hands-on AI & Python certificate workshop (14–15 Nov)',
            'Standard fee ₹1,499 · Early-bird / group of 3+ ₹999 (Discounts > ₹500 require Manager approval)',
            'Includes internship eligibility test & project certificate from Acadeno Research & Innovation Centre',
          ];

    final rawEmail =
        (data['email'] ?? data['emailAddress'] ?? data['emailId'] ?? '')
            .toString()
            .trim();
    final rawCourse =
        (data['course'] ?? data['workshop'] ?? data['program'] ?? '')
            .toString()
            .trim();
    final rawFee = (data['fee'] ?? data['courseFee'] ?? data['amount'] ?? '')
        .toString()
        .trim();
    final rawConsent =
        (data['consent'] ?? data['consentBasis'] ?? data['consentSource'] ?? '')
            .toString()
            .trim();

    return LeadRecord(
      id: id,
      name: rawName.isEmpty ? 'Unnamed' : rawName,
      phone: LeadPhoneValidator.formatDisplayPhone(
        rawPhone.isNotEmpty ? rawPhone : normPhone,
      ),
      phoneNormalized: normPhone,
      email: rawEmail,
      course: rawCourse,
      fee: rawFee,
      consent: rawConsent,
      collegeBranch: collegeBranch,
      college: college,
      branch: branch,
      year: year,
      source: source.isEmpty ? 'Direct visit' : source,
      status: status.isEmpty ? 'New' : status,
      lastContact: LeadDateHelper.formatLastContact(
        lastContactAt: data['lastContactAt'],
        lastCalledAt: data['lastCalledAt'],
        rawLastContact: lastContactField,
        updatedAt: updatedAtField,
        createdAt: createdAtField,
        status: status,
        timeline: timelineList,
      ),
      assignedToUid: assignedUidRaw.isEmpty ? null : assignedUidRaw,
      assignedToName: assignedNameRaw.isEmpty || assignedNameRaw == 'null'
          ? '—'
          : assignedNameRaw,
      assignedDateKey: data['assignedDateKey']?.toString(),
      assignedDateLabel: data['assignedDateLabel']?.toString(),
      assignedByUid: data['assignedByUid']?.toString(),
      assignedByName: data['assignedByName']?.toString(),
      assignedAt: assignedAtField is Timestamp
          ? assignedAtField.toDate()
          : (assignedAtField is DateTime ? assignedAtField : null),
      notes: (data['notes'] ?? '').toString(),
      isDone: data['isDone'] == true,
      isLocked: data['isLocked'] == true,
      lockedByUid: data['lockedByUid']?.toString(),
      lockedMessage: data['lockedMessage']?.toString(),
      talkingPoints: talkingPointsList,
      timeline: timelineList,
      createdByUid: data['createdByUid']?.toString(),
      createdByName: data['createdByName']?.toString(),
      createdAt: createdAtField is Timestamp
          ? createdAtField.toDate()
          : (createdAtField is DateTime ? createdAtField : null),
      updatedAt: updatedAtField is Timestamp
          ? updatedAtField.toDate()
          : (updatedAtField is DateTime ? updatedAtField : null),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    final parsed = parseCollegeBranch(collegeBranch);
    return {
      'name': name.trim(),
      'phone': LeadPhoneValidator.formatDisplayPhone(phone),
      'phoneNormalized': phoneNormalized,
      if (email.isNotEmpty) 'email': email.trim(),
      if (course.isNotEmpty) 'course': course.trim(),
      if (fee.isNotEmpty) 'fee': fee.trim(),
      if (consent.isNotEmpty) 'consent': consent.trim(),
      'collegeBranch': collegeBranch.trim(),
      'college': college.isNotEmpty ? college : parsed.college,
      'branch': branch.isNotEmpty ? branch : parsed.branch,
      'year': year.isNotEmpty ? year : parsed.year,
      'source': source.trim(),
      'status': status.trim(),
      'lastContact': lastContact,
      'assignedToUid': assignedToUid,
      'assignedToName': assignedToName,
      'assignedTo': assignedToName,
      'assignedDateKey': assignedDateKey,
      'assignedDateLabel': assignedDateLabel,
      'assignedByUid': assignedByUid,
      'assignedByName': assignedByName,
      'notes': notes,
      'isDone': isDone,
      'isLocked': isLocked,
      'lockedByUid': lockedByUid,
      'lockedMessage': lockedMessage,
      'talkingPoints': talkingPoints,
      'timeline': timeline,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
    };
  }

  LeadRecord copyWith({
    String? id,
    String? name,
    String? phone,
    String? phoneNormalized,
    String? email,
    String? course,
    String? fee,
    String? consent,
    String? collegeBranch,
    String? college,
    String? branch,
    String? year,
    String? source,
    String? status,
    String? lastContact,
    String? assignedToUid,
    String? assignedToName,
    String? assignedDateKey,
    String? assignedDateLabel,
    String? assignedByUid,
    String? assignedByName,
    DateTime? assignedAt,
    String? notes,
    bool? isDone,
    bool? isLocked,
    String? lockedByUid,
    String? lockedMessage,
    List<String>? talkingPoints,
    List<String>? timeline,
    String? createdByUid,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeadRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      phoneNormalized: phoneNormalized ?? this.phoneNormalized,
      email: email ?? this.email,
      course: course ?? this.course,
      fee: fee ?? this.fee,
      consent: consent ?? this.consent,
      collegeBranch: collegeBranch ?? this.collegeBranch,
      college: college ?? this.college,
      branch: branch ?? this.branch,
      year: year ?? this.year,
      source: source ?? this.source,
      status: status ?? this.status,
      lastContact: lastContact ?? this.lastContact,
      assignedToUid: assignedToUid ?? this.assignedToUid,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedDateKey: assignedDateKey ?? this.assignedDateKey,
      assignedDateLabel: assignedDateLabel ?? this.assignedDateLabel,
      assignedByUid: assignedByUid ?? this.assignedByUid,
      assignedByName: assignedByName ?? this.assignedByName,
      assignedAt: assignedAt ?? this.assignedAt,
      notes: notes ?? this.notes,
      isDone: isDone ?? this.isDone,
      isLocked: isLocked ?? this.isLocked,
      lockedByUid: lockedByUid ?? this.lockedByUid,
      lockedMessage: lockedMessage ?? this.lockedMessage,
      talkingPoints: talkingPoints ?? this.talkingPoints,
      timeline: timeline ?? this.timeline,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  ExecutiveLeadItem toExecutiveLeadItem({LeadAssignmentModel? assignment}) {
    final effectiveStatus = (status.isEmpty || status == 'New')
        ? 'Assigned'
        : status;
    final colors = ExecutiveLeadItem.statusColorsFor(effectiveStatus);
    final done = assignment != null ? assignment.isDone : isDone;
    return ExecutiveLeadItem(
      id: id,
      assignmentId: assignment?.id,
      name: name,
      initials: initials,
      maskedPhone: maskedPhone,
      fullPhone: phoneNormalized.isNotEmpty ? phoneNormalized : phone,
      collegeInfo: collegeBranch,
      statusTag: effectiveStatus,
      statusColor: colors.$1,
      statusBg: colors.$2,
      campaignTag: source,
      isLocked: isLocked,
      lockedMessage: lockedMessage,
      isDone: done,
      talkingPoints: talkingPoints,
      course: course.isNotEmpty ? course : (assignment?.course ?? ''),
      fee: fee.isNotEmpty ? fee : (assignment?.fee ?? ''),
      timeline: timeline.isNotEmpty
          ? timeline
          : [
              if (assignment != null)
                '${assignment.dateLabel} · Assigned to ${assignment.executiveName} by ${assignment.assignedByName}',
              'Registered via $source (Consent recorded)',
            ],
    );
  }
}

/// Firestore model for a document in the `assignments` collection.
class LeadAssignmentModel {
  final String id;
  final String leadId;
  final String executiveUid;
  final String executiveName;
  final String executiveEmail;
  final String dateKey;
  final String dateLabel;
  final String assignedByUid;
  final String assignedByName;
  final DateTime? assignedAt;
  final String? previousExecutiveUid;
  final String? previousExecutiveName;
  final DateTime? reassignedAt;
  final String status;
  final bool isDone;
  final String? lastOutcome;
  final String leadName;
  final String leadPhone;
  final String collegeBranch;
  final String source;
  final String leadStatus;
  final String course;
  final String fee;

  const LeadAssignmentModel({
    required this.id,
    required this.leadId,
    required this.executiveUid,
    required this.executiveName,
    this.executiveEmail = '',
    required this.dateKey,
    required this.dateLabel,
    required this.assignedByUid,
    required this.assignedByName,
    this.assignedAt,
    this.previousExecutiveUid,
    this.previousExecutiveName,
    this.reassignedAt,
    this.status = 'assigned',
    this.isDone = false,
    this.lastOutcome,
    this.leadName = '',
    this.leadPhone = '',
    this.collegeBranch = '',
    this.source = '',
    this.leadStatus = 'Assigned',
    this.course = '',
    this.fee = '',
  });

  /// Deterministic document ID preventing duplicate assignments for the same lead and date.
  static String docId(String leadId, String dateKey) => '${leadId}_$dateKey';

  factory LeadAssignmentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return LeadAssignmentModel.fromMap(doc.id, doc.data() ?? const {});
  }

  factory LeadAssignmentModel.fromMap(String id, Map<String, dynamic> data) {
    final assignedAtField = data['assignedAt'];
    final reassignedAtField = data['reassignedAt'];
    return LeadAssignmentModel(
      id: id,
      leadId: (data['leadId'] ?? '').toString(),
      executiveUid: (data['executiveUid'] ?? '').toString(),
      executiveName: (data['executiveName'] ?? '—').toString(),
      executiveEmail: (data['executiveEmail'] ?? '').toString(),
      dateKey: (data['dateKey'] ?? '').toString(),
      dateLabel: (data['dateLabel'] ?? '').toString(),
      assignedByUid: (data['assignedByUid'] ?? '').toString(),
      assignedByName: (data['assignedByName'] ?? 'Admin').toString(),
      assignedAt: assignedAtField is Timestamp
          ? assignedAtField.toDate()
          : (assignedAtField is DateTime ? assignedAtField : null),
      previousExecutiveUid: data['previousExecutiveUid']?.toString(),
      previousExecutiveName: data['previousExecutiveName']?.toString(),
      reassignedAt: reassignedAtField is Timestamp
          ? reassignedAtField.toDate()
          : (reassignedAtField is DateTime ? reassignedAtField : null),
      status: (data['status'] ?? 'assigned').toString(),
      isDone: data['isDone'] == true,
      lastOutcome: data['lastOutcome']?.toString(),
      leadName: (data['leadName'] ?? '').toString(),
      leadPhone: (data['leadPhone'] ?? '').toString(),
      collegeBranch: (data['collegeBranch'] ?? '').toString(),
      source: (data['source'] ?? 'Direct visit').toString(),
      leadStatus: (data['leadStatus'] ?? 'Assigned').toString(),
      course: (data['course'] ?? data['program'] ?? '').toString().trim(),
      fee: (data['fee'] ?? data['courseFee'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'leadId': leadId,
      'executiveUid': executiveUid,
      'executiveName': executiveName,
      'executiveEmail': executiveEmail,
      'dateKey': dateKey,
      'dateLabel': dateLabel,
      'assignedByUid': assignedByUid,
      'assignedByName': assignedByName,
      if (previousExecutiveUid != null)
        'previousExecutiveUid': previousExecutiveUid,
      if (previousExecutiveName != null)
        'previousExecutiveName': previousExecutiveName,
      'status': status,
      'isDone': isDone,
      if (lastOutcome != null) 'lastOutcome': lastOutcome,
      'leadName': leadName,
      'leadPhone': leadPhone,
      'collegeBranch': collegeBranch,
      'source': source,
      'leadStatus': leadStatus,
      if (course.isNotEmpty) 'course': course,
      if (fee.isNotEmpty) 'fee': fee,
    };
  }

  /// Fallback conversion if the underlying lead doc was not yet loaded.
  LeadRecord toFallbackLeadRecord() {
    final norm = LeadPhoneValidator.normalize10Digits(leadPhone);
    return LeadRecord(
      id: leadId,
      name: leadName.isEmpty ? 'Assigned Lead' : leadName,
      phone: LeadPhoneValidator.formatDisplayPhone(leadPhone),
      phoneNormalized: norm,
      collegeBranch: collegeBranch.isEmpty ? '—' : collegeBranch,
      source: source.isEmpty ? 'Direct visit' : source,
      status: lastOutcome ?? leadStatus,
      assignedToUid: executiveUid,
      assignedToName: executiveName,
      assignedDateKey: dateKey,
      assignedDateLabel: dateLabel,
      assignedByUid: assignedByUid,
      assignedByName: assignedByName,
      assignedAt: assignedAt,
      isDone: isDone,
      course: course,
      fee: fee,
    );
  }
}

class ExecutiveLeadItem {
  final String id;
  final String? assignmentId;
  final String name;
  final String initials;
  final String maskedPhone;
  final String fullPhone;
  final String collegeInfo;
  String statusTag;
  Color statusColor;
  Color statusBg;
  final String campaignTag;
  bool isLocked;
  String? lockedMessage;
  bool isDone;
  final List<String> talkingPoints;
  final List<String> timeline;
  final String course;
  final String fee;

  ExecutiveLeadItem({
    required this.id,
    this.assignmentId,
    required this.name,
    required this.initials,
    required this.maskedPhone,
    required this.fullPhone,
    required this.collegeInfo,
    required this.statusTag,
    required this.statusColor,
    required this.statusBg,
    required this.campaignTag,
    this.isLocked = false,
    this.lockedMessage,
    this.isDone = false,
    this.talkingPoints = const [
      '2-day hands-on AI & Python certificate workshop (14–15 Nov)',
      'Standard fee ₹1,499 · Early-bird / group of 3+ ₹999 (Discounts > ₹500 require Manager approval)',
      'Includes internship eligibility test & project certificate from Acadeno Research & Innovation Centre',
    ],
    this.timeline = const [
      '27 Oct, 9:20 AM · Assigned to Anjali R by Deepak PM',
      '24 Oct · Registered via College Webinar sheet (Consent recorded)',
    ],
    this.course = '',
    this.fee = '',
  });

  static (Color, Color) statusColorsFor(String status) {
    return switch (status) {
      'Interested' ||
      'Converted' => (const Color(0xFF15803D), const Color(0xFFE6F4EA)),
      'Follow-up' ||
      'Assigned' ||
      'New' => (const Color(0xFF3730A3), const Color(0xFFE8EDFF)),
      'Not interested' ||
      'Wrong number' => (const Color(0xFFB42318), const Color(0xFFFEE4E2)),
      _ => (const Color(0xFF344054), const Color(0xFFF2F4F7)),
    };
  }
}

class CallHistoryRecord {
  final String id;
  final String leadName;
  final String collegeInfo;
  final String campaign;
  final String outcome;
  final String duration;
  final String timestamp;
  final String notes;

  const CallHistoryRecord({
    required this.id,
    required this.leadName,
    required this.collegeInfo,
    required this.campaign,
    required this.outcome,
    required this.duration,
    required this.timestamp,
    required this.notes,
  });

  factory CallHistoryRecord.fromMap(String id, Map<String, dynamic> data) {
    return CallHistoryRecord(
      id: id,
      leadName: (data['leadName'] ?? 'Lead').toString(),
      collegeInfo: (data['collegeInfo'] ?? '—').toString(),
      campaign: (data['campaign'] ?? 'Direct visit').toString(),
      outcome: (data['outcome'] ?? 'Called').toString(),
      duration: (data['duration'] ?? '—').toString(),
      timestamp: LeadDateHelper.formatTimestamp(
        data['createdAt'] ?? data['timestamp'],
        fallback: 'Today',
      ),
      notes: (data['notes'] ?? '').toString(),
    );
  }
}

/// Active Sales Executive record loaded from the Firestore `users` collection.
class SalesExecutiveOption {
  final String uid;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final int assignedTodayCount;

  const SalesExecutiveOption({
    required this.uid,
    required this.name,
    required this.email,
    this.role = 'executive',
    this.isActive = true,
    this.assignedTodayCount = 0,
  });

  String dropdownLabel(int countForSelectedDate) =>
      '$name ($countForSelectedDate assigned)';

  factory SalesExecutiveOption.fromMap(String uid, Map<String, dynamic> data) {
    final rawName =
        (data['name'] ?? data['displayName'] ?? data['email'] ?? 'Executive')
            .toString()
            .trim();
    return SalesExecutiveOption(
      uid: (data['uid'] ?? uid).toString().trim().isEmpty
          ? uid
          : (data['uid'] ?? uid).toString().trim(),
      name: rawName.isEmpty ? 'Executive' : rawName,
      email: (data['email'] ?? '').toString().trim(),
      role: (data['role'] ?? 'executive').toString().trim(),
      isActive: data['isActive'] != false,
      assignedTodayCount: (data['assignedToday'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Summary returned after an Admin assigns or reassigns one or more leads.
class AssignmentBatchSummary {
  final List<LeadAssignmentModel> assignments;
  final int newlyAssignedCount;
  final int reassignedCount;
  final String executiveUid;
  final String executiveName;
  final String dateKey;
  final String dateLabel;

  const AssignmentBatchSummary({
    required this.assignments,
    required this.newlyAssignedCount,
    required this.reassignedCount,
    required this.executiveUid,
    required this.executiveName,
    required this.dateKey,
    required this.dateLabel,
  });

  int get totalCount => assignments.length;
}

/// Result of saving a mandatory call outcome (FR-3.2–3.5).
/// Lets the UI layer forward side-effects to the Follow-ups / Alerts features.
class CallOutcomeResult {
  final String collegeInfo;
  final bool needsDiscountApproval;

  const CallOutcomeResult({
    required this.collegeInfo,
    required this.needsDiscountApproval,
  });
}
