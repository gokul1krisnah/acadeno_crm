import 'package:intl/intl.dart';
import '../../../leads/data/model/lead_models.dart';

enum CallType { incoming, outgoing, missed, rejected, voicemail, unknown }

enum CallCategory { hotLead, followUp, reminder, other, none }

extension CallCategoryExtension on CallCategory {
  String get label {
    switch (this) {
      case CallCategory.hotLead:
        return 'Hot Leads';
      case CallCategory.followUp:
        return 'Follow-ups';
      case CallCategory.reminder:
        return 'Reminders';
      case CallCategory.other:
        return 'Other';
      case CallCategory.none:
        return 'None';
    }
  }

  String get dbValue {
    switch (this) {
      case CallCategory.hotLead:
        return 'hot_lead';
      case CallCategory.followUp:
        return 'follow_up';
      case CallCategory.reminder:
        return 'reminder';
      case CallCategory.other:
        return 'other';
      case CallCategory.none:
        return 'none';
    }
  }

  static CallCategory fromDbValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'hot_lead':
      case 'hotlead':
      case 'hot lead':
      case 'hot leads':
        return CallCategory.hotLead;
      case 'follow_up':
      case 'followup':
      case 'follow-up':
      case 'follow up':
      case 'follow-ups':
        return CallCategory.followUp;
      case 'reminder':
      case 'reminders':
        return CallCategory.reminder;
      case 'other':
      case 'others':
        return CallCategory.other;
      default:
        return CallCategory.none;
    }
  }
}

class DeviceCallLogItem {
  final String id;
  final String number;
  final String formattedNumber;
  final DateTime timestamp;
  final int durationSeconds;
  final CallType callType;
  final String simName;
  CallCategory category;
  String? linkedLeadId;
  String? notes;

  DeviceCallLogItem({
    required this.id,
    required this.number,
    required this.formattedNumber,
    required this.timestamp,
    required this.durationSeconds,
    required this.callType,
    this.simName = 'Mobile',
    this.category = CallCategory.none,
    this.linkedLeadId,
    this.notes,
  });

  /// Canonical 10-digit normalized phone number for database lookup.
  String get normalizedPhone => LeadPhoneValidator.normalize10Digits(number);

  /// Human-readable duration matching device style: e.g. "11m 50s", "0m 0s".
  String get formattedDuration {
    if (durationSeconds <= 0) return '0m 0s';
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  /// Relative and formatted date label: e.g. "Today, 9:48 AM", "Yesterday, 4:20 PM", "Jul 8, 9:49 AM".
  String get formattedDateTime {
    final now = DateTime.now();
    final isToday = now.year == timestamp.year &&
        now.month == timestamp.month &&
        now.day == timestamp.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == timestamp.year &&
        yesterday.month == timestamp.month &&
        yesterday.day == timestamp.day;

    final timeStr = DateFormat('h:mm a').format(timestamp);
    if (isToday) {
      return 'Today, $timeStr';
    } else if (isYesterday) {
      return 'Yesterday, $timeStr';
    } else if (now.year == timestamp.year) {
      return '${DateFormat('MMM d').format(timestamp)}, $timeStr';
    }
    return '${DateFormat('d MMM yyyy').format(timestamp)}, $timeStr';
  }

  factory DeviceCallLogItem.fromMap(Map<dynamic, dynamic> map) {
    final rawNumber = (map['number'] ?? '').toString().trim();
    final rawType = (map['type'] ?? '').toString().toLowerCase();

    CallType cType;
    switch (rawType) {
      case 'incoming':
        cType = CallType.incoming;
        break;
      case 'outgoing':
        cType = CallType.outgoing;
        break;
      case 'missed':
        cType = CallType.missed;
        break;
      case 'rejected':
      case 'blocked':
        cType = CallType.rejected;
        break;
      case 'voicemail':
        cType = CallType.voicemail;
        break;
      default:
        cType = CallType.unknown;
    }

    final ts = (map['timestamp'] is num)
        ? (map['timestamp'] as num).toInt()
        : int.tryParse(map['timestamp']?.toString() ?? '0') ?? 0;
    final dt = ts > 0
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : DateTime.now();

    final dur = (map['duration'] is num)
        ? (map['duration'] as num).toInt()
        : int.tryParse(map['duration']?.toString() ?? '0') ?? 0;

    final sim = (map['simName'] ?? 'Mobile').toString();

    // Format phone nicely: if 10-digit Indian, prefix +91
    String displayPhone = rawNumber;
    final norm10 = LeadPhoneValidator.normalize10Digits(rawNumber);
    if (norm10.length == 10 && !rawNumber.startsWith('+')) {
      displayPhone = '+91 $norm10';
    }

    return DeviceCallLogItem(
      id: (map['id'] ?? dt.millisecondsSinceEpoch.toString()).toString(),
      number: rawNumber,
      formattedNumber: displayPhone,
      timestamp: dt,
      durationSeconds: dur,
      callType: cType,
      simName: sim,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'formattedNumber': formattedNumber,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'durationSeconds': durationSeconds,
      'callType': callType.name,
      'simName': simName,
      'category': category.dbValue,
      'linkedLeadId': linkedLeadId,
      'notes': notes,
    };
  }
}
