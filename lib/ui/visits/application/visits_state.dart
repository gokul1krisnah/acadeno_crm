import '../data/model/visit_models.dart';

enum VisitStatusBucket {
  upcoming,
  completed,
  cancelled,
}

class VisitsState {
  final VisitStatusBucket selectedBucket;
  final List<ExecutiveCollegeVisit> visits;
  final String? toastMessage;
  final bool isLoading;

  const VisitsState({
    this.selectedBucket = VisitStatusBucket.upcoming,
    required this.visits,
    this.toastMessage,
    this.isLoading = false,
  });

  /// Planned visits appear under Upcoming
  List<ExecutiveCollegeVisit> get upcomingVisits => visits.where((v) {
        final s = v.statusLabel.trim().toLowerCase();
        return s == 'planned' ||
            s == 'upcoming' ||
            (s != 'completed' && s != 'cancelled' && s != 'canceled' && v.isUpcoming);
      }).toList();

  /// Completed visits appear under Completed
  List<ExecutiveCollegeVisit> get completedVisits => visits.where((v) {
        final s = v.statusLabel.trim().toLowerCase();
        return s == 'completed' ||
            (!v.isUpcoming && s != 'cancelled' && s != 'canceled');
      }).toList();

  /// Cancelled visits appear under Cancelled
  List<ExecutiveCollegeVisit> get cancelledVisits => visits.where((v) {
        final s = v.statusLabel.trim().toLowerCase();
        return s == 'cancelled' || s == 'canceled';
      }).toList();

  /// Backward-compatible alias for recentVisits
  List<ExecutiveCollegeVisit> get recentVisits => completedVisits;

  List<ExecutiveCollegeVisit> get activeBucketVisits => switch (selectedBucket) {
        VisitStatusBucket.upcoming => upcomingVisits,
        VisitStatusBucket.completed => completedVisits,
        VisitStatusBucket.cancelled => cancelledVisits,
      };

  int get upcomingCount => upcomingVisits.length;
  int get completedCount => completedVisits.length;
  int get cancelledCount => cancelledVisits.length;

  VisitsState copyWith({
    VisitStatusBucket? selectedBucket,
    List<ExecutiveCollegeVisit>? visits,
    String? toastMessage,
    bool clearToast = false,
    bool? isLoading,
  }) {
    return VisitsState(
      selectedBucket: selectedBucket ?? this.selectedBucket,
      visits: visits ?? this.visits,
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
