import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/model/call_log_model.dart';
import '../data/repository/call_logs_repo.dart';
import 'call_logs_state.dart';

class CallLogsCubit extends Cubit<CallLogsState> {
  final CallLogsRepository _repository;
  StreamSubscription? _catSub;

  CallLogsCubit(this._repository)
      : super(
          CallLogsState(
            isPlatformSupported: _repository.isPlatformSupported,
          ),
        ) {
    init();
  }

  Future<void> init() async {
    if (!_repository.isPlatformSupported) {
      emit(
        state.copyWith(
          isPlatformSupported: false,
          hasPermission: false,
          isPermissionDenied: false,
        ),
      );
      _listenSavedCategorizations();
      return;
    }

    emit(state.copyWith(isLoading: true));
    final hasPerm = await _repository.checkPermission();
    final hasContactsPerm = await _repository.checkContactsPermission();
    if (!hasPerm) {
      emit(
        state.copyWith(
          isLoading: false,
          hasPermission: false,
          hasContactsPermission: hasContactsPerm,
          isPermissionDenied: false,
        ),
      );
      _listenSavedCategorizations();
      return;
    }

    emit(
      state.copyWith(
        hasPermission: true,
        hasContactsPermission: hasContactsPerm,
        isPermissionDenied: false,
      ),
    );
    await _loadDeviceLogs();
    _listenSavedCategorizations();
  }

  void _listenSavedCategorizations() {
    _catSub?.cancel();
    _catSub = _repository.streamSavedCategorizations().listen(
      (savedMap) {
        final updatedLogs = _applyCategorizations(state.allLogs, savedMap);
        final filtered = _filterLogs(
          updatedLogs,
          state.activeCategoryFilter,
          state.searchQuery,
        );
        emit(
          state.copyWith(
            categorizations: savedMap,
            allLogs: updatedLogs,
            displayedLogs: filtered,
          ),
        );
      },
      onError: (_) {},
    );
  }

  Future<void> requestPermission() async {
    emit(state.copyWith(isLoading: true));
    final granted = await _repository.requestPermission();
    final hasContactsPerm = await _repository.checkContactsPermission();
    if (granted) {
      emit(
        state.copyWith(
          hasPermission: true,
          hasContactsPermission: hasContactsPerm,
          isPermissionDenied: false,
        ),
      );
      await _loadDeviceLogs();
    } else {
      emit(
        state.copyWith(
          isLoading: false,
          hasPermission: false,
          hasContactsPermission: hasContactsPerm,
          isPermissionDenied: true,
          toastMessage:
              'Call log permission was denied. Please allow it in settings.',
          isToastError: true,
        ),
      );
    }
  }

  Future<void> requestContactsPermission() async {
    if (!_repository.isPlatformSupported) return;
    final granted = await _repository.requestContactsPermission();
    emit(state.copyWith(hasContactsPermission: granted));
    if (granted) {
      await _loadDeviceLogs();
    } else {
      emit(
        state.copyWith(
          toastMessage:
              'Contacts permission not granted. Showing phone numbers only.',
          isToastError: false,
        ),
      );
    }
  }

  Future<void> refresh() async {
    if (!_repository.isPlatformSupported) return;
    final hasPerm = await _repository.checkPermission();
    final hasContactsPerm = await _repository.checkContactsPermission();
    if (!hasPerm) {
      emit(
        state.copyWith(
          hasPermission: false,
          hasContactsPermission: hasContactsPerm,
        ),
      );
      return;
    }
    emit(state.copyWith(hasContactsPermission: hasContactsPerm));
    await _loadDeviceLogs();
  }

  Future<void> _loadDeviceLogs() async {
    try {
      emit(state.copyWith(isLoading: true));
      final logs = await _repository.fetchDeviceCallLogs(limit: 100);
      final sim = logs.isNotEmpty ? logs.first.simName : 'Mobile';
      final withCats = _applyCategorizations(logs, state.categorizations);
      final filtered = _filterLogs(
        withCats,
        state.activeCategoryFilter,
        state.searchQuery,
      );

      emit(
        state.copyWith(
          isLoading: false,
          hasPermission: true,
          simName: sim,
          allLogs: withCats,
          displayedLogs: filtered,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          toastMessage: 'Failed to load call logs: $e',
          isToastError: true,
        ),
      );
    }
  }

  List<DeviceCallLogItem> _applyCategorizations(
    List<DeviceCallLogItem> logs,
    Map<String, CallCategory> map,
  ) {
    return logs.map((item) {
      final cat = map[item.normalizedPhone] ??
          map[item.id] ??
          map[item.number] ??
          item.category;
      item.category = cat;
      return item;
    }).toList();
  }

  Future<void> setCategory(
    DeviceCallLogItem item,
    CallCategory category,
  ) async {
    final previousCategory = item.category;
    final previousMap = Map<String, CallCategory>.from(state.categorizations);

    try {
      item.category = category;
      final updatedMap = Map<String, CallCategory>.from(state.categorizations);
      if (item.normalizedPhone.isNotEmpty) {
        updatedMap[item.normalizedPhone] = category;
      }
      updatedMap[item.id] = category;

      final updatedLogs = _applyCategorizations(state.allLogs, updatedMap);
      final filtered = _filterLogs(
        updatedLogs,
        state.activeCategoryFilter,
        state.searchQuery,
      );

      // Optimistic visual feedback while saving to Firestore
      emit(
        state.copyWith(
          categorizations: updatedMap,
          allLogs: updatedLogs,
          displayedLogs: filtered,
        ),
      );

      await _repository.saveCategorization(item: item, category: category);

      if (!isClosed) {
        emit(
          state.copyWith(
            toastMessage: 'Saved as ${category.label}',
            isToastError: false,
          ),
        );
      }
    } catch (e) {
      // Revert optimistic selection so UI stays consistent with Firestore
      item.category = previousCategory;
      final revertedLogs = _applyCategorizations(state.allLogs, previousMap);
      final revertedFiltered = _filterLogs(
        revertedLogs,
        state.activeCategoryFilter,
        state.searchQuery,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            categorizations: previousMap,
            allLogs: revertedLogs,
            displayedLogs: revertedFiltered,
            toastMessage: 'Failed to save ${category.label}. Please try again.',
            isToastError: true,
          ),
        );
      }
    }
  }

  /// Saves a detailed outcome from the "Other" popup.
  /// Updates the card category to `Other` only after Firestore confirms the save.
  /// Rethrows errors so the popup stays open and preserves user input.
  Future<void> saveOtherOutcome({
    required DeviceCallLogItem item,
    required String outcome,
    required String notes,
    String? courseEnrolled,
    String? batch,
    String? followUpTime,
  }) async {
    await _repository.saveOtherOutcome(
      item: item,
      outcome: outcome,
      notes: notes,
      courseEnrolled: courseEnrolled,
      batch: batch,
      followUpTime: followUpTime,
    );

    item.category = CallCategory.other;
    final updatedMap = Map<String, CallCategory>.from(state.categorizations);
    if (item.normalizedPhone.isNotEmpty) {
      updatedMap[item.normalizedPhone] = CallCategory.other;
    }
    updatedMap[item.id] = CallCategory.other;

    final updatedLogs = _applyCategorizations(state.allLogs, updatedMap);
    final filtered = _filterLogs(
      updatedLogs,
      state.activeCategoryFilter,
      state.searchQuery,
    );

    if (!isClosed) {
      emit(
        state.copyWith(
          categorizations: updatedMap,
          allLogs: updatedLogs,
          displayedLogs: filtered,
        ),
      );
    }
  }

  void setFilter(String filter) {
    final filtered = _filterLogs(state.allLogs, filter, state.searchQuery);
    emit(state.copyWith(activeCategoryFilter: filter, displayedLogs: filtered));
  }

  void search(String query) {
    final filtered = _filterLogs(
      state.allLogs,
      state.activeCategoryFilter,
      query,
    );
    emit(state.copyWith(searchQuery: query, displayedLogs: filtered));
  }

  List<DeviceCallLogItem> _filterLogs(
    List<DeviceCallLogItem> list,
    String categoryFilter,
    String query,
  ) {
    var result = list;
    if (categoryFilter != 'all') {
      final targetCat = CallCategoryExtension.fromDbValue(categoryFilter);
      result = result.where((i) => i.category == targetCat).toList();
    }

    if (query.trim().isNotEmpty) {
      final rawLower = query.trim().toLowerCase();
      final digits = query.trim().replaceAll(RegExp(r'\D'), '');
      result = result.where((i) {
        final nameMatch =
            i.hasContactName && i.contactName.toLowerCase().contains(rawLower);
        final phoneMatch = digits.isNotEmpty
            ? (i.normalizedPhone.contains(digits) ||
                  i.number.replaceAll(RegExp(r'\D'), '').contains(digits))
            : i.number.toLowerCase().contains(rawLower);
        return nameMatch || phoneMatch;
      }).toList();
    }

    return result;
  }

  void clearToast() {
    emit(state.copyWith(toastMessage: null));
  }

  @override
  Future<void> close() {
    _catSub?.cancel();
    return super.close();
  }
}
