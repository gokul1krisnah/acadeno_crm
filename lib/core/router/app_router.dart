import 'package:auto_route/auto_route.dart';

import '../../ui/auth/presentation/login_page.dart';
import '../../ui/dashboard/dashboard_page.dart';
import '../../ui/home/home_page.dart';
import '../../ui/splash/splash_page.dart';
part 'app_router.gr.dart';

// ---------------------------------------------------------------------------
// Admin session flag
// ---------------------------------------------------------------------------
/// Set to `true` only after a successful admin login or session restore.
/// Cleared on logout so that direct /dashboard URL navigation is blocked.
bool isAdminSession = false;

// ---------------------------------------------------------------------------
// Route guard – prevents unauthorized direct URL access to /dashboard
// ---------------------------------------------------------------------------
class AdminGuard extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (isAdminSession) {
      resolver.next(true); // allow
    } else {
      // Redirect through SplashRoute so app restarts restore the session first,
      // and unauthenticated users are routed to LoginRoute after splash.
      resolver.next(false);
      router.replaceAll([const SplashRoute()]);
    }
  }
}

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: SplashRoute.page, path: '/', initial: true),
    AutoRoute(page: LoginRoute.page, path: '/login'),
    // Admin dashboard — protected by AdminGuard
    AutoRoute(
      page: DashboardRoute.page,
      path: '/dashboard',
      guards: [AdminGuard()],
    ),
    // Normal user home page
    AutoRoute(page: HomeRoute.page, path: '/home'),
  ];
}
