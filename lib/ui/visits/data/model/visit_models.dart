class ExecutiveCollegeVisit {
  final String id;
  final String monthShort;
  final String dayNumber;
  final String collegeName;
  final String subtitle;
  String statusLabel; // 'Planned', 'Completed', 'Cancelled'
  final String purpose;
  final List<String> staffInitials;
  final String staffNames;
  int leadsCollected;
  int interestedCount;
  String metSummary;
  String nextActionSummary;
  bool isUpcoming;

  ExecutiveCollegeVisit({
    required this.id,
    required this.monthShort,
    required this.dayNumber,
    required this.collegeName,
    required this.subtitle,
    required this.statusLabel,
    this.purpose = '',
    this.staffInitials = const ['AR', 'RM'],
    this.staffNames = 'Anjali R, Rahul M',
    this.leadsCollected = 0,
    this.interestedCount = 0,
    this.metSummary = '',
    this.nextActionSummary = '',
    required this.isUpcoming,
  });
}
