import 'lead_models.dart';

/// Status classification of an individual row during bulk lead import (FR-1.2).
enum LeadImportStatus {
  /// Valid new lead, not present in file or database. Ready to import.
  valid,

  /// Matches a lead already present in the database (via 10-digit phone number).
  existing,

  /// Duplicate phone number within the uploaded file itself.
  duplicateInFile,

  /// Validation failure (missing name, invalid phone digits, bad email format).
  invalid,

  /// Successfully written to Firestore.
  imported,

  /// Skipped by Admin choice or duplicate handling policy.
  skipped,

  /// Failed during Firestore batch write.
  failed,
}

extension LeadImportStatusX on LeadImportStatus {
  String get label {
    return switch (this) {
      LeadImportStatus.valid => 'New lead',
      LeadImportStatus.existing => 'Already exists in database',
      LeadImportStatus.duplicateInFile => 'Duplicate in file',
      LeadImportStatus.invalid => 'Invalid row',
      LeadImportStatus.imported => 'Imported',
      LeadImportStatus.skipped => 'Skipped',
      LeadImportStatus.failed => 'Failed write',
    };
  }

  int get badgeBgHex {
    return switch (this) {
      LeadImportStatus.valid || LeadImportStatus.imported => 0xFFE6F4EA,
      LeadImportStatus.existing => 0xFFE8F1FD,
      LeadImportStatus.duplicateInFile => 0xFFFEF0E6,
      LeadImportStatus.invalid || LeadImportStatus.failed => 0xFFFEE4E2,
      LeadImportStatus.skipped => 0xFFF2F4F7,
    };
  }

  int get badgeFgHex {
    return switch (this) {
      LeadImportStatus.valid || LeadImportStatus.imported => 0xFF15803D,
      LeadImportStatus.existing => 0xFF1D4ED8,
      LeadImportStatus.duplicateInFile => 0xFF9A3412,
      LeadImportStatus.invalid || LeadImportStatus.failed => 0xFFB42318,
      LeadImportStatus.skipped => 0xFF475467,
    };
  }
}

/// A parsed lead candidate from a CSV or Excel row.
class LeadImportItem {
  final int rowNumber;
  String name;
  String phone;
  String phoneNormalized;
  String email;
  String college;
  String branch;
  String year;
  String course;
  String source;
  String notes;
  String consent;
  LeadImportStatus status;
  String issueMessage;
  String? existingLeadId;
  String? existingOwner;
  String? existingLeadName;
  bool isExcluded;

  LeadImportItem({
    required this.rowNumber,
    required this.name,
    required this.phone,
    required this.phoneNormalized,
    this.email = '',
    this.college = '',
    this.branch = '',
    this.year = '',
    this.course = '',
    this.source = '',
    this.notes = '',
    this.consent = '',
    this.status = LeadImportStatus.valid,
    this.issueMessage = '',
    this.existingLeadId,
    this.existingOwner,
    this.existingLeadName,
    this.isExcluded = false,
  });

  String get collegeBranch {
    final parts = [
      if (college.isNotEmpty) college,
      if (branch.isNotEmpty) branch,
      if (year.isNotEmpty) year,
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  String get maskedPhone => LeadPhoneValidator.maskPhone(
    phoneNormalized.isNotEmpty ? phoneNormalized : phone,
  );

  LeadRecord toLeadRecord({
    required String creatorUid,
    required String creatorName,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    return LeadRecord(
      id: '', // Will be assigned by Firestore doc ref
      name: name.trim(),
      phone: LeadPhoneValidator.formatDisplayPhone(
        phoneNormalized.isNotEmpty ? phoneNormalized : phone,
      ),
      phoneNormalized: phoneNormalized,
      email: email.trim(),
      course: course.trim(),
      consent: consent.trim(),
      collegeBranch: collegeBranch,
      college: college.trim(),
      branch: branch.trim(),
      year: year.trim(),
      source: source.trim().isNotEmpty ? source.trim() : 'Direct visit',
      status: 'New',
      lastContact: 'Just now',
      notes: notes.trim(),
      timeline: [
        '${LeadDateHelper.formatTimestamp(ts)} · Imported via Bulk Import by $creatorName (Consent: ${consent.isNotEmpty ? consent : "Recorded"})',
      ],
      createdByUid: creatorUid,
      createdByName: creatorName,
      createdAt: ts,
      updatedAt: ts,
    );
  }

  LeadImportItem copyWith({
    int? rowNumber,
    String? name,
    String? phone,
    String? phoneNormalized,
    String? email,
    String? college,
    String? branch,
    String? year,
    String? course,
    String? source,
    String? notes,
    String? consent,
    LeadImportStatus? status,
    String? issueMessage,
    String? existingLeadId,
    String? existingOwner,
    String? existingLeadName,
    bool? isExcluded,
  }) {
    return LeadImportItem(
      rowNumber: rowNumber ?? this.rowNumber,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      phoneNormalized: phoneNormalized ?? this.phoneNormalized,
      email: email ?? this.email,
      college: college ?? this.college,
      branch: branch ?? this.branch,
      year: year ?? this.year,
      course: course ?? this.course,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      consent: consent ?? this.consent,
      status: status ?? this.status,
      issueMessage: issueMessage ?? this.issueMessage,
      existingLeadId: existingLeadId ?? this.existingLeadId,
      existingOwner: existingOwner ?? this.existingOwner,
      existingLeadName: existingLeadName ?? this.existingLeadName,
      isExcluded: isExcluded ?? this.isExcluded,
    );
  }
}

/// Aggregate summary of an import execution.
class LeadImportSummary {
  final int totalRows;
  final int validCount;
  final int existingCount;
  final int duplicateInFileCount;
  final int invalidCount;
  final int importedCount;
  final int skippedCount;
  final int failedCount;
  final String fileName;
  final int fileSizeBytes;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String errorReportCsv;

  const LeadImportSummary({
    required this.totalRows,
    required this.validCount,
    required this.existingCount,
    required this.duplicateInFileCount,
    required this.invalidCount,
    required this.importedCount,
    required this.skippedCount,
    required this.failedCount,
    required this.fileName,
    required this.fileSizeBytes,
    required this.startedAt,
    this.completedAt,
    this.errorReportCsv = '',
  });

  bool get hasIssues => (invalidCount + duplicateInFileCount + failedCount) > 0;
}
