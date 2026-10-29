import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/model/lead_import_models.dart';
import '../data/model/lead_models.dart';
import '../data/repository/leads_repo.dart';
import '../data/sources/lead_import_parser.dart';
import 'lead_import_state.dart';

class LeadImportCubit extends Cubit<LeadImportState> {
  final LeadsRepository _repository;

  LeadImportCubit(this._repository) : super(LeadImportState.initial());

  void setStep(int step) {
    emit(state.copyWith(currentStep: step));
  }

  void setSourceEvent(String event) {
    emit(state.copyWith(sourceEvent: event));
  }

  void setConsentBasis(String consent) {
    emit(state.copyWith(consentBasis: consent));
  }

  void setFilter(String filter) {
    emit(state.copyWith(filter: filter));
  }

  void reset() {
    emit(LeadImportState.initial());
  }

  /// Loads the built-in realistic ACADENO webinar sample leads so Admin can test with 1 click.
  Future<void> loadSampleData() async {
    const sampleCsv = '''Name,Phone,Email,College,Branch,Year,Course,Source,Notes,Consent
Anand Kumar,9847011111,anand.k@example.com,NIT Calicut,CSE,3rd Year,AI & Python Bootcamp,AI & Machine Learning Workshop (Nov),Interested in weekend batch,Event registration form
Pooja Nair,9847022222,pooja.nair@gmail.com,CET Trivandrum,ECE,4th Year,Full Stack Flutter,AI & Machine Learning Workshop (Nov),Wants discount for group of 3,College attendance sheet
Mohammed R,9847033333,mohammed.r@outlook.com,GEC Thrissur,ME,2nd Year,Robotics & IoT,AI & Machine Learning Workshop (Nov),Follow up on Saturday,Website inquiry form
Arun Kumar,9847011111,arun.duplicate@gmail.com,NIT Calicut,CSE,3rd Year,AI Bootcamp,AI & Machine Learning Workshop (Nov),Duplicate phone number,Event registration form
Sneha Pillai,9847044444,sneha.p@yahoo.com,TKM Kollam,EEE,1st Year,Embedded Systems,AI & Machine Learning Workshop (Nov),Requested syllabus,Event registration form
Rahul M,98470,rahul@gmail.com,Model Engineering College,CS,3rd Year,AI Bootcamp,AI & Machine Learning Workshop (Nov),Invalid short phone,Event registration form
,9847055555,noname@gmail.com,GEC Barton Hill,IT,4th Year,Python,AI & Machine Learning Workshop (Nov),Name is blank,Event registration form
Divya Suresh,9847066666,divya.suresh@gmail.com,SCMS Cochin,MCA,2nd Year,Data Science,AI & Machine Learning Workshop (Nov),Needs loan assistance,Event registration form
''';
    await parseCsvContent(
      sampleCsv,
      'ai_webinar_registrations_oct.csv',
      fileSizeBytes: sampleCsv.length,
    );
  }

  /// Parses CSV string content, checks in-file duplicates, and verifies against Firestore.
  Future<void> parseCsvContent(
    String content,
    String fileName, {
    int fileSizeBytes = 0,
  }) async {
    emit(
      state.copyWith(
        isParsing: true,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
        clearError: true,
      ),
    );

    try {
      final parsed = LeadImportParser.parseCsvString(
        content,
        defaultSource: state.sourceEvent,
        defaultConsent: state.consentBasis,
      );

      emit(
        state.copyWith(
          isParsing: false,
          isVerifying: true,
          items: parsed,
          currentStep: 2,
        ),
      );

      // Verify candidates against Firestore lead_phones & leads
      final verified = await _repository.verifyImportAgainstFirestore(parsed);

      emit(state.copyWith(isVerifying: false, items: verified));
    } catch (err) {
      emit(
        state.copyWith(
          isParsing: false,
          isVerifying: false,
          errorMessage: 'Error parsing CSV: ${err.toString()}',
        ),
      );
    }
  }

  /// Parses file bytes (supports both .csv and .xlsx based on filename).
  Future<void> parseFileBytes(Uint8List bytes, String fileName) async {
    emit(
      state.copyWith(
        isParsing: true,
        fileName: fileName,
        fileSizeBytes: bytes.length,
        clearError: true,
      ),
    );

    try {
      List<LeadImportItem> parsed;
      final lowerName = fileName.toLowerCase();

      if (lowerName.endsWith('.xlsx')) {
        parsed = LeadImportParser.parseXlsxBytes(
          bytes,
          defaultSource: state.sourceEvent,
          defaultConsent: state.consentBasis,
        );
      } else {
        parsed = LeadImportParser.parseCsvBytes(
          bytes,
          defaultSource: state.sourceEvent,
          defaultConsent: state.consentBasis,
        );
      }

      emit(
        state.copyWith(
          isParsing: false,
          isVerifying: true,
          items: parsed,
          currentStep: 2,
        ),
      );

      // Verify candidates against Firestore lead_phones & leads
      final verified = await _repository.verifyImportAgainstFirestore(parsed);

      emit(state.copyWith(isVerifying: false, items: verified));
    } catch (err) {
      emit(
        state.copyWith(
          isParsing: false,
          isVerifying: false,
          errorMessage: 'Error parsing file ($fileName): ${err.toString()}',
        ),
      );
    }
  }

  /// Toggles inclusion/exclusion of a specific row before committing.
  void toggleExcludeRow(int rowNumber) {
    final updated = state.items.map((item) {
      if (item.rowNumber == rowNumber) {
        return item.copyWith(isExcluded: !item.isExcluded);
      }
      return item;
    }).toList();
    emit(state.copyWith(items: updated));
  }

  /// Allows correcting a row (e.g. fixing a typo in phone or name) in the preview table.
  void updateRowDetails(
    int rowNumber, {
    String? name,
    String? phone,
    String? email,
    String? college,
    String? branch,
    String? year,
  }) {
    final updated = state.items.map((item) {
      if (item.rowNumber == rowNumber) {
        final newName = (name ?? item.name).trim();
        final newPhone = (phone ?? item.phone).trim();
        final newEmail = (email ?? item.email).trim();
        final phone10 = LeadPhoneValidator.normalize10Digits(newPhone);

        var newStatus = item.status;
        var newIssue = item.issueMessage;

        if (newName.isEmpty) {
          newStatus = LeadImportStatus.invalid;
          newIssue = 'Name is missing – skipped';
        } else if (phone10.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(phone10)) {
          newStatus = LeadImportStatus.invalid;
          newIssue = 'Invalid phone (must be 10 digits starting with 6–9) – skipped';
        } else if (newEmail.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(newEmail)) {
          newStatus = LeadImportStatus.invalid;
          newIssue = 'Invalid email format – skipped';
        } else {
          newStatus = LeadImportStatus.valid;
          newIssue = 'Valid (edited by Admin)';
        }

        return item.copyWith(
          name: newName,
          phone: newPhone,
          phoneNormalized: phone10,
          email: newEmail,
          college: (college ?? item.college).trim(),
          branch: (branch ?? item.branch).trim(),
          year: (year ?? item.year).trim(),
          status: newStatus,
          issueMessage: newIssue,
        );
      }
      return item;
    }).toList();

    emit(state.copyWith(items: updated));
  }

  /// Executes the bulk import to Firestore with progress tracking and batched writes.
  Future<LeadImportSummary?> executeImport({bool skipExisting = true}) async {
    if (state.isImporting) return null;

    final candidates = state.items
        .where(
          (i) =>
              !i.isExcluded &&
              (i.status == LeadImportStatus.valid ||
                  (i.status == LeadImportStatus.existing && !skipExisting)),
        )
        .toList();

    emit(
      state.copyWith(
        isImporting: true,
        processedCount: 0,
        totalCandidates: candidates.length,
        clearError: true,
      ),
    );

    try {
      final summary = await _repository.executeBulkImport(
        items: state.items,
        sourceEvent: state.sourceEvent,
        consentBasis: state.consentBasis,
        fileName: state.fileName.isNotEmpty ? state.fileName : 'imported_leads.csv',
        fileSizeBytes: state.fileSizeBytes,
        skipExisting: skipExisting,
        onProgress: (processed, total) {
          if (!isClosed) {
            emit(
              state.copyWith(
                processedCount: processed,
                totalCandidates: total,
              ),
            );
          }
        },
      );

      emit(
        state.copyWith(
          isImporting: false,
          currentStep: 3,
          summary: summary,
          items: List.from(state.items),
        ),
      );

      return summary;
    } catch (err) {
      emit(
        state.copyWith(
          isImporting: false,
          errorMessage: 'Failed to import leads: ${err.toString()}',
        ),
      );
      return null;
    }
  }
}

