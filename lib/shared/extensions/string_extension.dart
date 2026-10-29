extension StringExtension on String {
  String formatUrl() {
    if (isEmpty) return this;
    if (_isValidAbsoluteUrl()) return this;
    return this;
  }

  bool _isValidAbsoluteUrl() {
    final uri = Uri.tryParse(this);
    return uri != null && uri.hasScheme && _isHttpScheme(uri.scheme) && uri.host.isNotEmpty;
  }

  bool _isHttpScheme(String scheme) {
    final lowerScheme = scheme.toLowerCase();
    return lowerScheme == 'http' || lowerScheme == 'https';
  }

  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

extension TimeFormatter on String {
  String getWeekdayLabel() {
    final givenDate = DateTime.tryParse(this);
    if (givenDate == null) return '';
    final date = givenDate.toLocal();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    }

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    return '$day $month ${date.year}';
  }

  bool isToday() {
    final dateTime = DateTime.tryParse(this)?.toLocal();
    if (dateTime == null) return false;
    final now = DateTime.now();
    return dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day;
  }

  String toTimeAgoOrTime() {
    final dateTime = DateTime.tryParse(this)?.toLocal();
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (now.year == dateTime.year && now.month == dateTime.month && now.day == dateTime.day) {
      final hoursAgo = difference.inHours;
      if (hoursAgo >= 1) {
        return '$hoursAgo hours ago';
      } else if (difference.inMinutes >= 1) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } else {
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }
  }

  bool isOnSameDay(String? date) {
    if (date == null) return false;
    final currentDay = DateTime.tryParse(this)?.toLocal();
    final prevDay = DateTime.tryParse(date)?.toLocal();
    if (currentDay == null || prevDay == null) return false;

    return currentDay.year == prevDay.year &&
        currentDay.month == prevDay.month &&
        currentDay.day == prevDay.day;
  }
}
