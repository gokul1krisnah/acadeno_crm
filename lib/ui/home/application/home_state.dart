import '../data/model/home_user_model.dart';

/// Shell state for the executive home screen: bottom navigation + the
/// signed-in user's profile. Each tab owns its own state in its feature
/// folder (`leads`, `follow_ups`, `visits`, `alerts`).
class HomeState {
  final int bottomNavIndex;
  final HomeUserModel user;

  const HomeState({this.bottomNavIndex = 0, this.user = HomeUserModel.empty});

  /// "Good morning" / "Good afternoon" / "Good evening" by local time.
  String get greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// e.g. "Thu, 29 Oct"
  String get todayLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]}';
  }

  HomeState copyWith({int? bottomNavIndex, HomeUserModel? user}) {
    return HomeState(
      bottomNavIndex: bottomNavIndex ?? this.bottomNavIndex,
      user: user ?? this.user,
    );
  }
}
