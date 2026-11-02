import 'package:intl/intl.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/model/lead_models.dart';
import '../data/repository/leads_repo.dart';
import 'admin_leads_state.dart';

class AdminLeadsCubit extends Cubit<AdminLeadsState> {
  final LeadsRepository _repository;

  StreamSubscription<List<LeadRecord>>? _leadsSub;
  StreamSubscription<List<SalesExecutiveOption>>? _executivesSub;
  StreamSubscription<List<LeadAssignmentModel>>? _assignmentsSub;

  AdminLeadsCubit(this._repository, {DateTime? now})
    : super(AdminLeadsState.initial(now: now)) {
    _subscribeAll();
  }

  void _subscribeAll() {
    _leadsSub?.cancel();
    _executivesSub?.cancel();
    _assignmentsSub?.cancel();

    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        isPermissionDenied: false,
      ),
    );

    _leadsSub = _repository.watchAllLeads().listen(
      (leads) {
        if (isClosed) return;
        // Prune selected IDs that no longer exist
        final existingIds = leads.map((l) => l.id).toSet();
        final validSelected = state.selectedLeadIds.intersection(existingIds);
        emit(
          state.copyWith(
            isLoading: false,
            clearError: true,
            isPermissionDenied: false,
            allLeads: leads,
            selectedLeadIds: validSelected,
          ),
        );
      },
      onError: (Object error) {
        if (isClosed) return;
        final isPerm =
            error is LeadPermissionException ||
            (error is FirebaseException && error.code == 'permission-denied') ||
            error.toString().toLowerCase().contains('permission');
        emit(
          state.copyWith(
            isLoading: false,
            isPermissionDenied: isPerm,
            errorMessage: _cleanError(error),
          ),
        );
      },
    );

    _executivesSub = _repository.watchActiveExecutives().listen(
      (execs) {
        if (isClosed) return;
        String? nextSelectedUid = state.selectedExecutiveUid;
        if (execs.isNotEmpty &&
            (nextSelectedUid == null ||
                !execs.any((e) => e.uid == nextSelectedUid))) {
          nextSelectedUid = execs.first.uid;
        }
        emit(
          state.copyWith(
            activeExecutives: execs,
            selectedExecutiveUid: nextSelectedUid,
          ),
        );
      },
      onError: (_) {
        // Non-fatal if users query hasn't resolved yet
      },
    );

    _subscribeAssignmentsForDate(state.selectedDateKey);
  }

  void _subscribeAssignmentsForDate(String dateKey) {
    _assignmentsSub?.cancel();
    _assignmentsSub = _repository.watchAssignmentsForDate(dateKey).listen((
      assignments,
    ) {
      if (isClosed) return;
      emit(state.copyWith(dateAssignments: assignments));
    }, onError: (_) {});
  }

  void refresh() => _subscribeAll();

  void clearToast() {
    if (state.toastMessage != null) {
      emit(state.copyWith(clearToast: true));
    }
  }

  // ---------------------------------------------------------------------------
  // Search, Filters & Pagination
  // ---------------------------------------------------------------------------

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query, currentPage: 1, clearToast: true));
  }

  void setSourceFilter(String value) {
    emit(state.copyWith(sourceFilter: value, currentPage: 1, clearToast: true));
  }

  void setCollegeFilter(String value) {
    emit(
      state.copyWith(collegeFilter: value, currentPage: 1, clearToast: true),
    );
  }

  void setBranchFilter(String value) {
    emit(state.copyWith(branchFilter: value, currentPage: 1, clearToast: true));
  }

  void setYearFilter(String value) {
    emit(state.copyWith(yearFilter: value, currentPage: 1, clearToast: true));
  }

  void setStatusFilter(String value) {
    emit(state.copyWith(statusFilter: value, currentPage: 1, clearToast: true));
  }

  void resetFilters() {
    emit(
      state.copyWith(
        searchQuery: '',
        sourceFilter: 'All sources',
        collegeFilter: 'All colleges',
        branchFilter: 'All branches',
        yearFilter: 'Any year',
        statusFilter: 'All statuses',
        currentPage: 1,
        clearToast: true,
      ),
    );
  }

  void nextPage() {
    if (state.safeCurrentPage < state.totalPages) {
      emit(state.copyWith(currentPage: state.safeCurrentPage + 1));
    }
  }

  void previousPage() {
    if (state.safeCurrentPage > 1) {
      emit(state.copyWith(currentPage: state.safeCurrentPage - 1));
    }
  }

  // ---------------------------------------------------------------------------
  // Selection & Assignment Controls
  // ---------------------------------------------------------------------------

  void toggleLeadSelection(String leadId, bool selected) {
    final next = Set<String>.from(state.selectedLeadIds);
    if (selected) {
      next.add(leadId);
    } else {
      next.remove(leadId);
    }
    emit(state.copyWith(selectedLeadIds: next, clearToast: true));
  }

  void toggleSelectAllOnPage(bool selected) {
    final next = Set<String>.from(state.selectedLeadIds);
    for (final lead in state.paginatedLeads) {
      if (selected) {
        next.add(lead.id);
      } else {
        next.remove(lead.id);
      }
    }
    emit(state.copyWith(selectedLeadIds: next, clearToast: true));
  }

  void clearSelection() {
    emit(state.copyWith(selectedLeadIds: const {}, clearToast: true));
  }

  void selectExecutive(String executiveUid) {
    emit(state.copyWith(selectedExecutiveUid: executiveUid, clearToast: true));
  }

  void selectAssignmentDate(String dateKey) {
    final match = state.dateOptions.where((d) => d.dateKey == dateKey);
    final label = match.isNotEmpty ? match.first.label : dateKey;
    emit(
      state.copyWith(
        selectedDateKey: dateKey,
        selectedDateLabel: label,
        clearToast: true,
      ),
    );
    _subscribeAssignmentsForDate(dateKey);
  }

  void selectCustomAssignmentDate(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final label = DateFormat('EEE, d MMM').format(date);
    final exists = state.dateOptions.any((d) => d.dateKey == key);
    final updatedOptions = exists
        ? state.dateOptions
        : [...state.dateOptions, (dateKey: key, label: label)];

    emit(
      state.copyWith(
        dateOptions: updatedOptions,
        selectedDateKey: key,
        selectedDateLabel: label,
        clearToast: true,
      ),
    );
    _subscribeAssignmentsForDate(key);
  }

  // ---------------------------------------------------------------------------
  // Create & Edit Lead
  // ---------------------------------------------------------------------------

  Future<LeadRecord?> createLead({
    required String name,
    required String phone,
    required String collegeBranch,
    required String source,
    String status = 'New',
    String notes = '',
    bool autoSelectNewLead = true,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearToast: true));
    try {
      final created = await _repository.createLead(
        name: name,
        phone: phone,
        collegeBranch: collegeBranch,
        source: source,
        status: status,
        notes: notes,
      );
      final nextSelected = Set<String>.from(state.selectedLeadIds);
      if (autoSelectNewLead) {
        nextSelected.add(created.id);
      }
      emit(
        state.copyWith(
          isSubmitting: false,
          selectedLeadIds: nextSelected,
          toastMessage: 'Added lead ${created.name} (${created.phone})',
          isToastError: false,
        ),
      );
      return created;
    } on DuplicateLeadException catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          toastMessage: e.toString(),
          isToastError: true,
        ),
      );
      rethrow;
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          toastMessage: _cleanError(e),
          isToastError: true,
        ),
      );
      rethrow;
    }
  }

  Future<LeadRecord?> updateLead({
    required String leadId,
    required String name,
    required String phone,
    required String collegeBranch,
    required String source,
    required String status,
    String? notes,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearToast: true));
    try {
      final updated = await _repository.updateLead(
        leadId: leadId,
        name: name,
        phone: phone,
        collegeBranch: collegeBranch,
        source: source,
        status: status,
        notes: notes,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          toastMessage: 'Updated lead ${updated.name}',
          isToastError: false,
        ),
      );
      return updated;
    } on DuplicateLeadException catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          toastMessage: e.toString(),
          isToastError: true,
        ),
      );
      rethrow;
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          toastMessage: _cleanError(e),
          isToastError: true,
        ),
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Admin Lead Assignment & Reassignment
  // ---------------------------------------------------------------------------

  Future<AssignmentBatchSummary?> assignSelectedLeads({
    bool allowReassign = false,
  }) async {
    final exec = state.selectedExecutive;
    if (exec == null) {
      emit(
        state.copyWith(
          toastMessage:
              'No active Sales Executive available in users collection.',
          isToastError: true,
        ),
      );
      return null;
    }
    return assignLeads(
      leadIds: state.selectedLeadIds.toList(),
      executiveUid: exec.uid,
      dateKey: state.selectedDateKey,
      dateLabel: state.selectedDateLabel,
      allowReassign: allowReassign,
    );
  }

  Future<AssignmentBatchSummary?> assignLeads({
    required List<String> leadIds,
    required String executiveUid,
    String? dateKey,
    String? dateLabel,
    bool allowReassign = false,
  }) async {
    if (leadIds.isEmpty) {
      emit(
        state.copyWith(
          toastMessage: 'Select at least one lead to assign.',
          isToastError: true,
        ),
      );
      return null;
    }

    emit(state.copyWith(isSubmitting: true, clearToast: true));
    try {
      final summary = await _repository.assignLeadsToExecutive(
        leadIds: leadIds,
        executiveUid: executiveUid,
        dateKey: dateKey ?? state.selectedDateKey,
        dateLabel: dateLabel ?? state.selectedDateLabel,
        allowReassign: allowReassign,
      );

      final remainingSelected = Set<String>.from(state.selectedLeadIds)
        ..removeAll(leadIds);

      final msg = summary.reassignedCount > 0 && summary.newlyAssignedCount > 0
          ? 'Assigned ${summary.newlyAssignedCount} & reassigned ${summary.reassignedCount} leads to ${summary.executiveName} for ${summary.dateLabel}'
          : summary.reassignedCount > 0
          ? 'Reassigned ${summary.reassignedCount} ${summary.reassignedCount == 1 ? "lead" : "leads"} to ${summary.executiveName} for ${summary.dateLabel}'
          : 'Assigned ${summary.totalCount} ${summary.totalCount == 1 ? "lead" : "leads"} to ${summary.executiveName} for ${summary.dateLabel}';

      emit(
        state.copyWith(
          isSubmitting: false,
          selectedLeadIds: remainingSelected,
          toastMessage: msg,
          isToastError: false,
        ),
      );
      return summary;
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          toastMessage: _cleanError(e),
          isToastError: true,
        ),
      );
      return null;
    }
  }

  static String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Bad state: ', '');
  }

  @override
  Future<void> close() async {
    await _leadsSub?.cancel();
    await _executivesSub?.cancel();
    await _assignmentsSub?.cancel();
    return super.close();
  }
}
