import '../data/model/lead_models.dart';

class LeadsState {
  final bool isLoading;
  final String? errorMessage;
  final bool isPermissionDenied;
  final bool showingPendingCalls;
  final List<ExecutiveLeadItem> leads;
  final List<CallHistoryRecord> callRecords;
  final int phoneLookupsThisHour;
  final String? toastMessage;
  final bool isToastError;

  const LeadsState({
    this.isLoading = false,
    this.errorMessage,
    this.isPermissionDenied = false,
    this.showingPendingCalls = true,
    required this.leads,
    required this.callRecords,
    this.phoneLookupsThisHour = 0,
    this.toastMessage,
    this.isToastError = false,
  });

  List<ExecutiveLeadItem> get pendingLeads =>
      leads.where((l) => !l.isDone).toList();

  List<ExecutiveLeadItem> get doneLeads =>
      leads.where((l) => l.isDone).toList();

  /// Returns the top urgent lead for the "DUE NOW" card on the Today Dashboard,
  /// or `null` if no pending leads are assigned.
  ExecutiveLeadItem? get dueNowLead =>
      pendingLeads.isNotEmpty ? pendingLeads.first : null;

  int get totalCallsAssigned => leads.length;
  int get callsDoneCount => doneLeads.length;
  int get callsLeftCount => pendingLeads.length;

  int get progressPercent => totalCallsAssigned == 0
      ? 0
      : ((callsDoneCount / totalCallsAssigned) * 100).round();

  LeadsState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? isPermissionDenied,
    bool? showingPendingCalls,
    List<ExecutiveLeadItem>? leads,
    List<CallHistoryRecord>? callRecords,
    int? phoneLookupsThisHour,
    String? toastMessage,
    bool? isToastError,
    bool clearToast = false,
  }) {
    return LeadsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
      showingPendingCalls: showingPendingCalls ?? this.showingPendingCalls,
      leads: leads ?? this.leads,
      callRecords: callRecords ?? this.callRecords,
      phoneLookupsThisHour: phoneLookupsThisHour ?? this.phoneLookupsThisHour,
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
      isToastError: clearToast ? false : (isToastError ?? this.isToastError),
    );
  }
}
