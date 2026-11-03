sealed class DashboardState {
  const DashboardState({this.selectedNavIndex = 0});

  final int selectedNavIndex;
}

class DashboardInitial extends DashboardState {
  const DashboardInitial({super.selectedNavIndex = 0});
}

class DashboardLoading extends DashboardState {
  const DashboardLoading({super.selectedNavIndex = 0});
}

class DashboardActionSuccess extends DashboardState {
  const DashboardActionSuccess({
    required this.message,
    super.selectedNavIndex = 0,
  });

  final String message;
}

class DashboardActionFailure extends DashboardState {
  const DashboardActionFailure({
    required this.message,
    super.selectedNavIndex = 0,
  });

  final String message;
}

class DashboardSignedOut extends DashboardState {
  const DashboardSignedOut({super.selectedNavIndex = 0});
}
