import '../data/model/call_log_model.dart';

class CallLogsState {
  final bool isLoading;
  final bool hasPermission;
  final bool hasContactsPermission;
  final bool isPermissionDenied;
  final bool isPlatformSupported;
  final String simName;
  final List<DeviceCallLogItem> allLogs;
  final List<DeviceCallLogItem> displayedLogs;
  final Map<String, CallCategory> categorizations;
  final String activeCategoryFilter; // 'all', 'hot_lead', 'follow_up', 'reminder', 'other'
  final String searchQuery;
  final String? toastMessage;
  final bool isToastError;

  const CallLogsState({
    this.isLoading = false,
    this.hasPermission = false,
    this.hasContactsPermission = false,
    this.isPermissionDenied = false,
    this.isPlatformSupported = true,
    this.simName = 'Mobile',
    this.allLogs = const [],
    this.displayedLogs = const [],
    this.categorizations = const {},
    this.activeCategoryFilter = 'all',
    this.searchQuery = '',
    this.toastMessage,
    this.isToastError = false,
  });

  CallLogsState copyWith({
    bool? isLoading,
    bool? hasPermission,
    bool? hasContactsPermission,
    bool? isPermissionDenied,
    bool? isPlatformSupported,
    String? simName,
    List<DeviceCallLogItem>? allLogs,
    List<DeviceCallLogItem>? displayedLogs,
    Map<String, CallCategory>? categorizations,
    String? activeCategoryFilter,
    String? searchQuery,
    String? toastMessage,
    bool? isToastError,
  }) {
    return CallLogsState(
      isLoading: isLoading ?? this.isLoading,
      hasPermission: hasPermission ?? this.hasPermission,
      hasContactsPermission:
          hasContactsPermission ?? this.hasContactsPermission,
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
      isPlatformSupported: isPlatformSupported ?? this.isPlatformSupported,
      simName: simName ?? this.simName,
      allLogs: allLogs ?? this.allLogs,
      displayedLogs: displayedLogs ?? this.displayedLogs,
      categorizations: categorizations ?? this.categorizations,
      activeCategoryFilter: activeCategoryFilter ?? this.activeCategoryFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      toastMessage: toastMessage,
      isToastError: isToastError ?? this.isToastError,
    );
  }
}
