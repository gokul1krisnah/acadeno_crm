import '../data/model/lead_import_models.dart';

class LeadImportState {
  final int currentStep;
  final bool isParsing;
  final bool isVerifying;
  final bool isImporting;
  final String fileName;
  final int fileSizeBytes;
  final String sourceEvent;
  final String consentBasis;
  final List<LeadImportItem> items;
  final String filter; // 'all', 'new', 'existing', 'issues'
  final int processedCount;
  final int totalCandidates;
  final LeadImportSummary? summary;
  final String? errorMessage;

  const LeadImportState({
    this.currentStep = 1,
    this.isParsing = false,
    this.isVerifying = false,
    this.isImporting = false,
    this.fileName = '',
    this.fileSizeBytes = 0,
    this.sourceEvent = 'AI & Machine Learning Workshop (Nov)',
    this.consentBasis = 'Event registration form',
    this.items = const [],
    this.filter = 'all',
    this.processedCount = 0,
    this.totalCandidates = 0,
    this.summary,
    this.errorMessage,
  });

  factory LeadImportState.initial() => const LeadImportState();

  int get newLeadsCount => items
      .where((i) => i.status == LeadImportStatus.valid && !i.isExcluded)
      .length;

  int get existingLeadsCount => items
      .where((i) => i.status == LeadImportStatus.existing && !i.isExcluded)
      .length;

  int get skippedLeadsCount => items
      .where(
        (i) =>
            i.isExcluded ||
            i.status == LeadImportStatus.invalid ||
            i.status == LeadImportStatus.duplicateInFile,
      )
      .length;

  int get importableTotal => newLeadsCount + existingLeadsCount;

  List<LeadImportItem> get filteredItems {
    return switch (filter) {
      'new' => items.where((i) => i.status == LeadImportStatus.valid).toList(),
      'existing' =>
        items.where((i) => i.status == LeadImportStatus.existing).toList(),
      'issues' =>
        items
            .where(
              (i) =>
                  i.status == LeadImportStatus.invalid ||
                  i.status == LeadImportStatus.duplicateInFile ||
                  i.status == LeadImportStatus.failed,
            )
            .toList(),
      _ => items,
    };
  }

  LeadImportState copyWith({
    int? currentStep,
    bool? isParsing,
    bool? isVerifying,
    bool? isImporting,
    String? fileName,
    int? fileSizeBytes,
    String? sourceEvent,
    String? consentBasis,
    List<LeadImportItem>? items,
    String? filter,
    int? processedCount,
    int? totalCandidates,
    LeadImportSummary? summary,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LeadImportState(
      currentStep: currentStep ?? this.currentStep,
      isParsing: isParsing ?? this.isParsing,
      isVerifying: isVerifying ?? this.isVerifying,
      isImporting: isImporting ?? this.isImporting,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      sourceEvent: sourceEvent ?? this.sourceEvent,
      consentBasis: consentBasis ?? this.consentBasis,
      items: items ?? this.items,
      filter: filter ?? this.filter,
      processedCount: processedCount ?? this.processedCount,
      totalCandidates: totalCandidates ?? this.totalCandidates,
      summary: summary ?? this.summary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
