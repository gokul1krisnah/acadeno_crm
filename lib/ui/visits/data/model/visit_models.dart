class ExecutiveCollegeVisit {
  final String id;
  final String monthShort;
  final String dayNumber;
  final String collegeName;
  final String subtitle;
  String statusLabel; // 'Planned', 'Completed', 'Cancelled'
  final String purpose;
  final String sourceEvent;
  final String content;
  final List<String> staffInitials;
  final String staffNames;
  int leadsCollected;
  int interestedCount;
  String metSummary;
  String nextActionSummary;
  String cancelReason;
  bool isUpcoming;

  ExecutiveCollegeVisit({
    required this.id,
    required this.monthShort,
    required this.dayNumber,
    required this.collegeName,
    required this.subtitle,
    required this.statusLabel,
    this.purpose = '',
    this.sourceEvent = '',
    this.content = '',
    this.staffInitials = const ['AR', 'RM'],
    this.staffNames = 'Anjali R, Rahul M',
    this.leadsCollected = 0,
    this.interestedCount = 0,
    this.metSummary = '',
    this.nextActionSummary = '',
    this.cancelReason = '',
    required this.isUpcoming,
  });

  ExecutiveCollegeVisit copyWith({
    String? id,
    String? monthShort,
    String? dayNumber,
    String? collegeName,
    String? subtitle,
    String? statusLabel,
    String? purpose,
    String? sourceEvent,
    String? content,
    List<String>? staffInitials,
    String? staffNames,
    int? leadsCollected,
    int? interestedCount,
    String? metSummary,
    String? nextActionSummary,
    String? cancelReason,
    bool? isUpcoming,
  }) {
    return ExecutiveCollegeVisit(
      id: id ?? this.id,
      monthShort: monthShort ?? this.monthShort,
      dayNumber: dayNumber ?? this.dayNumber,
      collegeName: collegeName ?? this.collegeName,
      subtitle: subtitle ?? this.subtitle,
      statusLabel: statusLabel ?? this.statusLabel,
      purpose: purpose ?? this.purpose,
      sourceEvent: sourceEvent ?? this.sourceEvent,
      content: content ?? this.content,
      staffInitials: staffInitials ?? this.staffInitials,
      staffNames: staffNames ?? this.staffNames,
      leadsCollected: leadsCollected ?? this.leadsCollected,
      interestedCount: interestedCount ?? this.interestedCount,
      metSummary: metSummary ?? this.metSummary,
      nextActionSummary: nextActionSummary ?? this.nextActionSummary,
      cancelReason: cancelReason ?? this.cancelReason,
      isUpcoming: isUpcoming ?? this.isUpcoming,
    );
  }
}
