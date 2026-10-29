import '../data/model/lead_models.dart';

class AdminLeadsState {
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final bool isPermissionDenied;
  final List<LeadRecord> allLeads;
  final List<SalesExecutiveOption> activeExecutives;
  final List<LeadAssignmentModel> dateAssignments;
  final Set<String> selectedLeadIds;
  final String? selectedExecutiveUid;
  final String selectedDateKey;
  final String selectedDateLabel;
  final List<({String dateKey, String label})> dateOptions;

  // Search & 5 filter controls
  final String searchQuery;
  final String sourceFilter;
  final String collegeFilter;
  final String branchFilter;
  final String yearFilter;
  final String statusFilter;

  // Pagination
  final int currentPage;
  final int pageSize;

  // Feedback toast
  final String? toastMessage;
  final bool isToastError;

  const AdminLeadsState({
    this.isLoading = true,
    this.isSubmitting = false,
    this.errorMessage,
    this.isPermissionDenied = false,
    this.allLeads = const [],
    this.activeExecutives = const [],
    this.dateAssignments = const [],
    this.selectedLeadIds = const {},
    this.selectedExecutiveUid,
    required this.selectedDateKey,
    required this.selectedDateLabel,
    required this.dateOptions,
    this.searchQuery = '',
    this.sourceFilter = 'All sources',
    this.collegeFilter = 'All colleges',
    this.branchFilter = 'All branches',
    this.yearFilter = 'Any year',
    this.statusFilter = 'All statuses',
    this.currentPage = 1,
    this.pageSize = 10,
    this.toastMessage,
    this.isToastError = false,
  });

  factory AdminLeadsState.initial({DateTime? now}) {
    final dates = LeadDateHelper.upcomingAssignmentDates(now);
    return AdminLeadsState(
      selectedDateKey: dates.first.dateKey,
      selectedDateLabel: dates.first.label,
      dateOptions: dates,
    );
  }

  SalesExecutiveOption? get selectedExecutive {
    if (activeExecutives.isEmpty) return null;
    if (selectedExecutiveUid != null) {
      for (final e in activeExecutives) {
        if (e.uid == selectedExecutiveUid) return e;
      }
    }
    return activeExecutives.first;
  }

  /// Number of leads assigned to [executiveUid] for [selectedDateKey].
  int assignmentCountForExecutive(String executiveUid) {
    final fromAssignments = dateAssignments
        .where((a) => a.executiveUid == executiveUid)
        .length;
    if (fromAssignments > 0) return fromAssignments;
    return allLeads
        .where(
          (l) =>
              l.assignedToUid == executiveUid &&
              (l.assignedDateKey == null ||
                  l.assignedDateKey == selectedDateKey),
        )
        .length;
  }

  /// Filtered leads based on search query and all 5 filter dropdowns.
  List<LeadRecord> get filteredLeads {
    final q = searchQuery.trim().toLowerCase();
    return allLeads.where((l) {
      if (q.isNotEmpty) {
        final matchName = l.name.toLowerCase().contains(q);
        final matchPhone =
            l.phone.toLowerCase().contains(q) || l.phoneNormalized.contains(q);
        final matchCollege = l.collegeBranch.toLowerCase().contains(q);
        final matchAssigned = l.assignedToName.toLowerCase().contains(q);
        if (!matchName && !matchPhone && !matchCollege && !matchAssigned) {
          return false;
        }
      }
      if (sourceFilter != 'All sources' &&
          l.source.toLowerCase() != sourceFilter.toLowerCase()) {
        return false;
      }
      if (collegeFilter != 'All colleges' &&
          !l.collegeBranch.toLowerCase().contains(
            collegeFilter.toLowerCase(),
          ) &&
          l.college.toLowerCase() != collegeFilter.toLowerCase()) {
        return false;
      }
      if (branchFilter != 'All branches') {
        if (branchFilter == 'CSE, ECE') {
          final cb = l.collegeBranch.toUpperCase();
          if (!cb.contains('CSE') && !cb.contains('ECE')) return false;
        } else if (!l.collegeBranch.toLowerCase().contains(
              branchFilter.toLowerCase(),
            ) &&
            l.branch.toLowerCase() != branchFilter.toLowerCase()) {
          return false;
        }
      }
      if (yearFilter != 'Any year') {
        final yrDigit = yearFilter.replaceAll(RegExp(r'\D'), '');
        if (yrDigit.isNotEmpty &&
            !l.collegeBranch.contains(yrDigit) &&
            !l.year.contains(yrDigit)) {
          return false;
        }
      }
      if (statusFilter != 'All statuses') {
        if (statusFilter == 'New, No answer') {
          final st = l.status.toLowerCase();
          if (st != 'new' && st != 'no answer') return false;
        } else if (l.status.toLowerCase() != statusFilter.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  int get totalPages {
    final total = filteredLeads.length;
    if (total == 0) return 1;
    return ((total - 1) ~/ pageSize) + 1;
  }

  int get safeCurrentPage => currentPage.clamp(1, totalPages);

  List<LeadRecord> get paginatedLeads {
    final all = filteredLeads;
    if (all.isEmpty) return const [];
    final start = (safeCurrentPage - 1) * pageSize;
    if (start >= all.length) return const [];
    final end = (start + pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  int get showingStartIndex =>
      filteredLeads.isEmpty ? 0 : ((safeCurrentPage - 1) * pageSize) + 1;

  int get showingEndIndex => filteredLeads.isEmpty
      ? 0
      : (showingStartIndex + paginatedLeads.length - 1);

  List<LeadRecord> get selectedLeadRecords =>
      allLeads.where((l) => selectedLeadIds.contains(l.id)).toList();

  /// Returns selected leads that are already assigned for [selectedDateKey].
  List<LeadRecord> get conflictingSelectedLeads {
    final assignedLeadIdsForDate = {
      for (final a in dateAssignments) a.leadId: a,
    };
    return selectedLeadRecords.where((l) {
      if (assignedLeadIdsForDate.containsKey(l.id)) return true;
      return l.isAssigned && l.assignedDateKey == selectedDateKey;
    }).toList();
  }

  AdminLeadsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool? isPermissionDenied,
    List<LeadRecord>? allLeads,
    List<SalesExecutiveOption>? activeExecutives,
    List<LeadAssignmentModel>? dateAssignments,
    Set<String>? selectedLeadIds,
    String? selectedExecutiveUid,
    String? selectedDateKey,
    String? selectedDateLabel,
    List<({String dateKey, String label})>? dateOptions,
    String? searchQuery,
    String? sourceFilter,
    String? collegeFilter,
    String? branchFilter,
    String? yearFilter,
    String? statusFilter,
    int? currentPage,
    int? pageSize,
    String? toastMessage,
    bool? isToastError,
    bool clearToast = false,
  }) {
    return AdminLeadsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
      allLeads: allLeads ?? this.allLeads,
      activeExecutives: activeExecutives ?? this.activeExecutives,
      dateAssignments: dateAssignments ?? this.dateAssignments,
      selectedLeadIds: selectedLeadIds ?? this.selectedLeadIds,
      selectedExecutiveUid: selectedExecutiveUid ?? this.selectedExecutiveUid,
      selectedDateKey: selectedDateKey ?? this.selectedDateKey,
      selectedDateLabel: selectedDateLabel ?? this.selectedDateLabel,
      dateOptions: dateOptions ?? this.dateOptions,
      searchQuery: searchQuery ?? this.searchQuery,
      sourceFilter: sourceFilter ?? this.sourceFilter,
      collegeFilter: collegeFilter ?? this.collegeFilter,
      branchFilter: branchFilter ?? this.branchFilter,
      yearFilter: yearFilter ?? this.yearFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
      isToastError: clearToast ? false : (isToastError ?? this.isToastError),
    );
  }
}
