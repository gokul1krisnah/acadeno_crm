enum FollowUpBucket { overdue, today, upcoming }

class ExecutiveFollowUpItem {
  final String id;
  final String leadName;
  final String maskedPhone;
  final String phone;
  final String collegeInfo;
  String timeLabel;
  final String channelLabel; // 'Call', 'Auto-retry', 'WhatsApp'
  String note;
  FollowUpBucket bucket;
  bool isCompleted;
  final DateTime? scheduledTime;
  final String? assignedToName;
  final String? assignedToUid;

  ExecutiveFollowUpItem({
    required this.id,
    required this.leadName,
    required this.maskedPhone,
    this.phone = '',
    required this.collegeInfo,
    required this.timeLabel,
    required this.channelLabel,
    required this.note,
    required this.bucket,
    this.isCompleted = false,
    this.scheduledTime,
    this.assignedToName,
    this.assignedToUid,
  });
}
