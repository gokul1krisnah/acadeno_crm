import '../data/model/visit_models.dart';

class VisitsState {
  final List<ExecutiveCollegeVisit> visits;
  final String? toastMessage;

  const VisitsState({required this.visits, this.toastMessage});

  List<ExecutiveCollegeVisit> get upcomingVisits =>
      visits.where((v) => v.isUpcoming).toList();

  List<ExecutiveCollegeVisit> get recentVisits =>
      visits.where((v) => !v.isUpcoming).toList();

  VisitsState copyWith({
    List<ExecutiveCollegeVisit>? visits,
    String? toastMessage,
    bool clearToast = false,
  }) {
    return VisitsState(
      visits: visits ?? this.visits,
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
    );
  }
}
