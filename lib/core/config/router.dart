import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/providers/onboarding_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/customer/presentation/screens/customer_home_page.dart';
import '../../features/rider/presentation/screens/rider_home_page.dart';
import '../../features/rider/presentation/screens/rider_register_screen.dart';
import '../../features/rider/presentation/screens/rider_dashboard_screen.dart';
import '../../features/rider/presentation/screens/route_optimization_screen.dart';
import '../../features/rider/presentation/screens/rider_collection_screen.dart';
import '../../features/rider/presentation/screens/performance_analytics_screen.dart';
import '../../features/rider/presentation/screens/rider_profile_screen.dart';
import '../../features/rider/presentation/screens/rider_notifications_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard.dart';

part 'router.g.dart';

class RiverpodRefreshListenable extends ChangeNotifier {
  RiverpodRefreshListenable(Ref ref) {
    ref.listen<AuthState>(
      authStateControllerProvider,
      (previous, next) {
        notifyListeners();
      },
    );
    ref.listen<bool>(
      onboardingControllerProvider,
      (previous, next) {
        notifyListeners();
      },
    );
  }
}

@riverpod
GoRouter router(Ref ref) {
  final refreshListenable = RiverpodRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authStateControllerProvider);
      final loc = state.uri.path;

      // If we are currently loading the auth state (e.g. at startup),
      // do not redirect to login yet to allow Splash Screen to run.
      if (authState is AuthLoading) {
        return null;
      }

      final user = authState is AuthAuthenticated ? authState.user : null;
      final isLoggedIn = user != null;

      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/forgot-password' ||
          loc == '/onboarding' ||
          loc == '/rider/register' ||
          loc == '/';

      if (!isLoggedIn) {
        final completedOnboarding = ref.read(onboardingControllerProvider);
        if (!completedOnboarding) {
          return loc == '/onboarding' || loc == '/' ? null : '/onboarding';
        }
        // If not logged in, only allow auth routes or splash route
        return isAuthRoute ? null : '/login';
      }

      // If logged in and attempting to visit an auth/splash/onboarding route, redirect to their home
      if (isAuthRoute) {
        return _getDashboardRoute(user.role);
      }

      // Protect Customer routes
      if (loc.startsWith('/customer/') && user.role != UserRole.customer) {
        return _getDashboardRoute(user.role);
      }

      // Protect Rider routes
      if (loc.startsWith('/rider/') && user.role != UserRole.rider) {
        return _getDashboardRoute(user.role);
      }

      // Protect Admin routes
      if (loc.startsWith('/admin/') && user.role != UserRole.admin) {
        return _getDashboardRoute(user.role);
      }

      return null; // Proceed on current route
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/rider/register',
        builder: (context, state) => const RiderRegisterScreen(),
      ),
      GoRoute(
        path: '/customer/home',
        builder: (context, state) => const CustomerHomePage(),
      ),
      GoRoute(
        path: '/rider/home',
        builder: (context, state) => const RiderDashboardScreen(),
      ),
      GoRoute(
        path: '/rider/dashboard',
        builder: (context, state) => const RiderDashboardScreen(),
      ),
      GoRoute(
        path: '/rider/route',
        builder: (context, state) => const RouteOptimizationScreen(),
      ),
      GoRoute(
        path: '/rider/collection',
        builder: (context, state) => const RiderCollectionScreen(),
      ),
      GoRoute(
        path: '/rider/performance',
        builder: (context, state) => const PerformanceAnalyticsScreen(),
      ),
      GoRoute(
        path: '/rider/profile',
        builder: (context, state) => const RiderProfileScreen(),
      ),
      GoRoute(
        path: '/rider/notifications',
        builder: (context, state) => const RiderNotificationsScreen(),
      ),
      GoRoute(
        path: '/admin/home',
        builder: (context, state) => const AdminDashboard(),
      ),
    ],
  );
}

String _getDashboardRoute(UserRole role) {
  switch (role) {
    case UserRole.customer:
      return '/customer/home';
    case UserRole.rider:
      return '/rider/home';
    case UserRole.admin:
      return '/admin/home';
  }
}


