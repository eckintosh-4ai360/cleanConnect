import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/providers/onboarding_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/customer/presentation/screens/customer_dashboard_screen.dart';
import '../../features/customer/presentation/screens/bin_management_screen.dart';
import '../../features/customer/presentation/screens/bin_register_screen.dart';
import '../../features/customer/presentation/screens/pickup_request_screen.dart';
import '../../features/customer/presentation/screens/pickup_confirmed_screen.dart';
import '../../features/customer/presentation/screens/service_history_screen.dart';
import '../../features/customer/presentation/screens/collection_detail_screen.dart';
import '../../features/customer/presentation/screens/subscription_screen.dart';
import '../../features/customer/presentation/screens/profile_settings_screen.dart';
import '../../features/customer/presentation/screens/support_home_screen.dart';
import '../../features/customer/presentation/screens/report_incident_screen.dart';
import '../../features/customer/presentation/screens/track_pickup_screen.dart';
import '../../features/rider/presentation/screens/rider_register_screen.dart';
import '../../features/rider/presentation/screens/rider_dashboard_screen.dart';
import '../../features/rider/presentation/screens/route_optimization_screen.dart';
import '../../features/rider/presentation/screens/rider_collection_screen.dart';
import '../../features/rider/presentation/screens/performance_analytics_screen.dart';
import '../../features/rider/presentation/screens/rider_profile_screen.dart';
import '../../features/rider/presentation/screens/rider_notifications_screen.dart';
import '../../features/rider/presentation/screens/rider_help_support_screen.dart';
import '../../features/rider/presentation/screens/rider_privacy_policy_screen.dart';
import '../../features/rider/presentation/screens/available_pickups_screen.dart';
import '../../features/rider/presentation/screens/rider_navigation_screen.dart';
import '../../features/rider/presentation/screens/incoming_pickup_request_screen.dart';
import '../../features/rider/presentation/screens/assigned_reports_screen.dart';
import '../../features/rider/domain/entities/pickup_request_entity.dart';
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

      // Wait for auth to resolve before redirecting from splash
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
        return isAuthRoute ? null : '/login';
      }

      // Redirect authenticated users away from auth pages
      if (isAuthRoute) {
        return _getDashboardRoute(user.role);
      }

      // Role-based route guards
      if (loc.startsWith('/customer/') && user.role != UserRole.customer) {
        return _getDashboardRoute(user.role);
      }

      if (loc.startsWith('/rider/') && user.role != UserRole.rider) {
        return _getDashboardRoute(user.role);
      }

      if (loc.startsWith('/admin/') && user.role != UserRole.admin) {
        return _getDashboardRoute(user.role);
      }

      return null;
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
        builder: (context, state) => const CustomerDashboardScreen(),
      ),
      GoRoute(
        path: '/customer/dashboard',
        builder: (context, state) => const CustomerDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const CustomerDashboardScreen(),
      ),
      GoRoute(
        path: '/customer/bins',
        builder: (context, state) => const BinManagementScreen(),
      ),
      GoRoute(
        path: '/customer/register-bin',
        builder: (context, state) => const BinRegisterScreen(),
      ),
      GoRoute(
        path: '/customer/request-pickup',
        builder: (context, state) => const PickupRequestScreen(),
      ),
      GoRoute(
        path: '/customer/pickup-confirmed',
        builder: (context, state) => const PickupConfirmedScreen(),
      ),
      GoRoute(
        path: '/customer/history',
        builder: (context, state) => const ServiceHistoryScreen(),
      ),
      GoRoute(
        path: '/customer/collection-detail',
        builder: (context, state) {
          final recordId = state.extra as String? ?? 'REC-001';
          return CollectionDetailScreen(recordId: recordId);
        },
      ),
      GoRoute(
        path: '/customer/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/customer/profile',
        builder: (context, state) => const ProfileSettingsScreen(),
      ),
      GoRoute(
        path: '/customer/support',
        builder: (context, state) => const SupportHomeScreen(),
      ),
      GoRoute(
        path: '/customer/report-incident',
        builder: (context, state) => const ReportIncidentScreen(),
      ),
      GoRoute(
        // Optional requestId in state.extra tracks a specific booking
        path: '/customer/track',
        builder: (context, state) =>
            TrackPickupScreen(requestId: state.extra as String?),
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
        builder: (context, state) {
          final pickup = state.extra as PickupRequestEntity?;
          return RiderCollectionScreen(pickup: pickup);
        },
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
        path: '/rider/help-support',
        builder: (context, state) => const RiderHelpSupportScreen(),
      ),
      GoRoute(
        path: '/rider/privacy-policy',
        builder: (context, state) => const RiderPrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/rider/pickups',
        builder: (context, state) => const AvailablePickupsScreen(),
      ),
      GoRoute(
        path: '/rider/navigation',
        builder: (context, state) {
          final pickup = state.extra as PickupRequestEntity?;
          return RiderNavigationScreen(pickup: pickup);
        },
      ),
      GoRoute(
        path: '/rider/incoming-request/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          return IncomingPickupRequestScreen(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/rider/incident-reports',
        builder: (context, state) => const AssignedReportsScreen(),
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

