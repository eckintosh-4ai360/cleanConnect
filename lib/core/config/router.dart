import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/customer/presentation/screens/customer_dashboard_screen.dart';
import '../../features/customer/presentation/screens/bin_register_screen.dart';
import '../../features/customer/presentation/screens/bin_management_screen.dart';
import '../../features/customer/presentation/screens/subscription_screen.dart';
import '../../features/customer/presentation/screens/pickup_request_screen.dart';
import '../../features/customer/presentation/screens/pickup_confirmed_screen.dart';
import '../../features/customer/presentation/screens/service_history_screen.dart';
import '../../features/customer/presentation/screens/collection_detail_screen.dart';
import '../../features/customer/presentation/screens/profile_settings_screen.dart';
import '../../features/customer/presentation/screens/support_home_screen.dart';
// Rider screens
import '../../features/rider/presentation/screens/rider_register_screen.dart';
import '../../features/rider/presentation/screens/rider_dashboard_screen.dart';
import '../../features/rider/presentation/screens/route_optimization_screen.dart';
import '../../features/rider/presentation/screens/rider_collection_screen.dart';
import '../../features/rider/presentation/screens/performance_analytics_screen.dart';
import '../../features/rider/presentation/screens/rider_profile_screen.dart';
import '../../features/rider/presentation/screens/rider_notifications_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ── Auth ─────────────────────────────────────────────────────────────
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
      path: '/otp',
      builder: (context, state) {
        final phoneNumber =
            state.uri.queryParameters['phone'] ?? '+1 (555) 019-2834';
        return OtpVerificationScreen(phoneNumber: phoneNumber);
      },
    ),

    // ── Customer ─────────────────────────────────────────────────────────
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const CustomerDashboardScreen(),
    ),
    GoRoute(
      path: '/customer/register-bin',
      builder: (context, state) => const BinRegisterScreen(),
    ),
    GoRoute(
      path: '/customer/bins',
      builder: (context, state) => const BinManagementScreen(),
    ),
    GoRoute(
      path: '/customer/subscription',
      builder: (context, state) => const SubscriptionScreen(),
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
      path: '/customer/service-record',
      builder: (context, state) {
        final recordId = state.uri.queryParameters['id'] ?? 'rec_1';
        return CollectionDetailScreen(recordId: recordId);
      },
    ),
    GoRoute(
      path: '/customer/profile',
      builder: (context, state) => const ProfileSettingsScreen(),
    ),
    GoRoute(
      path: '/customer/support',
      builder: (context, state) => const SupportHomeScreen(),
    ),

    // ── Rider ─────────────────────────────────────────────────────────────
    GoRoute(
      path: '/rider/register',
      builder: (context, state) => const RiderRegisterScreen(),
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
  ],
);


