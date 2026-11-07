enum AlertIconType { phone, reassign, sun, clock, warning, list }

class ExecutiveAlertItem {
  final String id;
  final String title;
  final String subtitle;
  final String timeLabel;
  final AlertIconType iconType;
  final bool isToday;
  bool isUnread;
  final int? targetTabIndex;
  final String? targetLeadName;
  final DateTime createdAt;

  ExecutiveAlertItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.iconType,
    required this.isToday,
    required this.isUnread,
    this.targetTabIndex,
    this.targetLeadName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
