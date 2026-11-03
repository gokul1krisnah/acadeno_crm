import '../data/model/follow_up_models.dart';

class FollowUpsState {
  final FollowUpBucket selectedFollowUpBucket;
  final List<ExecutiveFollowUpItem> followUps;
  final String? toastMessage;
  final bool isLoading;

  const FollowUpsState({
    this.selectedFollowUpBucket = FollowUpBucket.today,
    required this.followUps,
    this.toastMessage,
    this.isLoading = false,
  });

  List<ExecutiveFollowUpItem> get overdueFollowUps => followUps
      .where((f) => !f.isCompleted && f.bucket == FollowUpBucket.overdue)
      .toList();

  List<ExecutiveFollowUpItem> get todayFollowUps => followUps
      .where((f) => !f.isCompleted && f.bucket == FollowUpBucket.today)
      .toList();

  List<ExecutiveFollowUpItem> get upcomingFollowUps => followUps
      .where((f) => !f.isCompleted && f.bucket == FollowUpBucket.upcoming)
      .toList();

  List<ExecutiveFollowUpItem> get activeBucketFollowUps =>
      switch (selectedFollowUpBucket) {
        FollowUpBucket.overdue => overdueFollowUps,
        FollowUpBucket.today => todayFollowUps,
        FollowUpBucket.upcoming => upcomingFollowUps,
      };

  FollowUpsState copyWith({
    FollowUpBucket? selectedFollowUpBucket,
    List<ExecutiveFollowUpItem>? followUps,
    String? toastMessage,
    bool clearToast = false,
    bool? isLoading,
  }) {
    return FollowUpsState(
      selectedFollowUpBucket:
          selectedFollowUpBucket ?? this.selectedFollowUpBucket,
      followUps: followUps ?? this.followUps,
      toastMessage: clearToast ? null : (toastMessage ?? this.toastMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
