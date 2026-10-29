enum FollowUpBucket { overdue, today, upcoming }

class ExecutiveFollowUpItem {
  final String id;
  final String leadName;
  final String maskedPhone;
  final String collegeInfo;
  String timeLabel;
  final String channelLabel; // 'Call', 'Auto-retry', 'WhatsApp'
  String note;
  FollowUpBucket bucket;
  bool isCompleted;

  ExecutiveFollowUpItem({
    required this.id,
    required this.leadName,
    required this.maskedPhone,
    required this.collegeInfo,
    required this.timeLabel,
    required this.channelLabel,
    required this.note,
    required this.bucket,
    this.isCompleted = false,
  });
}
