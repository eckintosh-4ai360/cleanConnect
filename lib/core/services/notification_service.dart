import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/rider/presentation/providers/rider_providers.dart';
import '../../firebase_options.dart';
import '../config/router.dart';

const String pickupRequestsChannelId = 'pickup_requests_channel';
const String pickupRequestsChannelName = 'New Pickup Requests';
const List<int> _pickupVibrationPatternRaw = [0, 1000, 500, 1000, 500, 1000];

const String _riderPushEnabledKey = 'rider_push_alerts_enabled';

// SharedPreferences is used here so both background and main isolates can read it
final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Checks if device is logged in as a rider to avoid showing rider alerts to non-riders
Future<bool> _riderPushEnabled() async {
  try {
    return await _prefs.getBool(_riderPushEnabledKey) ?? true;
  } catch (_) {
    return true;
  }
}

Future<void> _setRiderPushEnabled(bool enabled) async {
  try {
    await _prefs.setBool(_riderPushEnabledKey, enabled);
  } catch (_) {}
}

// Background FCM entry point (must be top-level pragma vm:entry-point)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (message.data['type'] != 'new_pickup_request') return;
  if (!await _riderPushEnabled()) return;
  await _ensureLocalNotifications();
  await _showIncomingPickupNotification(message.data);
}

// Setup local notification channel for pickup requests
bool _localNotificationsReady = false;
Future<void> _ensureLocalNotifications({
  void Function(String? payload)? onTap,
}) async {
  if (_localNotificationsReady) return;

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await _localNotificationsPlugin.initialize(
    settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    onDidReceiveNotificationResponse: (response) => onTap?.call(response.payload),
  );

  final channel = AndroidNotificationChannel(
    pickupRequestsChannelId,
    pickupRequestsChannelName,
    description: 'Alerts riders when a new pickup request comes in.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList(_pickupVibrationPatternRaw),
  );

  await _localNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  _localNotificationsReady = true;
}

Future<void> _showIncomingPickupNotification(Map<String, dynamic> data) async {
  final androidDetails = AndroidNotificationDetails(
    pickupRequestsChannelId,
    pickupRequestsChannelName,
    channelDescription: 'Alerts riders when a new pickup request comes in.',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.call,
    ongoing: true,
    autoCancel: false,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList(_pickupVibrationPatternRaw),
    visibility: NotificationVisibility.public,
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  final requestId = data['requestId'] as String? ?? '';
  final customerName = data['customerName'] as String? ?? 'A customer';
  final location = data['location'] as String? ?? '';

  await _localNotificationsPlugin.show(
    id: requestId.hashCode,
    title: 'New pickup request',
    body: location.isNotEmpty ? '$customerName • $location' : customerName,
    notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: requestId,
  );
}

/// Manages FCM push alerts, local notifications, and vibration for rider pickup requests.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Max vibration duration safeguard (30s)
  static const Duration _maxVibrationDuration = Duration(seconds: 30);

  ProviderContainer? _container;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  ProviderSubscription<AuthState>? _authSub;
  String? _lastNavigatedRequestId;
  DateTime? _lastNavigatedAt;
  String? _pendingRequestId;
  Timer? _vibrationTimeout;
  final FlutterRingtonePlayer _ringtonePlayer = FlutterRingtonePlayer();

  Future<void> initialize(ProviderContainer container) async {
    _container = container;

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _ensureLocalNotifications(onTap: _navigateToRequestId);

    _onMessageSub =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    _onTokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen(_syncToken);

    _authSub = container.listen<AuthState>(
      authStateControllerProvider,
      (previous, next) => unawaited(_handleAuthStateChange(next)),
      fireImmediately: true,
    );

    // Handle cold start from terminated push tap
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null &&
        initialMessage.data['type'] == 'new_pickup_request') {
      _navigateToRequestId(initialMessage.data['requestId'] as String?);
    }

    // Handle cold start from local notification tap
    final launchDetails =
        await _localNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _navigateToRequestId(launchDetails?.notificationResponse?.payload);
    }
  }

  // Syncs FCM token for riders and clears notifications when logging out
  Future<void> _handleAuthStateChange(AuthState state) async {
    if (state is AuthLoading) return;

    final isRider =
        state is AuthAuthenticated && state.user.role == UserRole.rider;
    await _setRiderPushEnabled(isRider);

    if (isRider) {
      await _refreshAndSyncToken();
      final pending = _pendingRequestId;
      _pendingRequestId = null;
      if (pending != null) _navigateToRequestId(pending);
      return;
    }

    // Silence and clean up notifications for non-riders
    _pendingRequestId = null;
    await stopIncomingPickupAlert();
    await _cancelAllPickupNotifications();
    if (state is AuthAuthenticated) {
      await _releaseStaleDeviceToken();
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (message.data['type'] != 'new_pickup_request') return;
    if (!_isSignedInAsRider) {
      unawaited(_releaseStaleDeviceToken());
      return;
    }
    unawaited(startIncomingPickupAlert());
    _navigateToRequestId(message.data['requestId'] as String?);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    if (message.data['type'] != 'new_pickup_request') return;
    _navigateToRequestId(message.data['requestId'] as String?);
  }

  bool get _isSignedInAsRider =>
      _container?.read(currentUserRoleProvider) == UserRole.rider;

  void _navigateToRequestId(String? requestId) {
    if (requestId == null || requestId.isEmpty || _container == null) return;

    final role = _container!.read(currentUserRoleProvider);
    if (role == null) {
      // Hold request until auth state resolves
      _pendingRequestId = requestId;
      return;
    }
    if (role != UserRole.rider) return;

    // Throttle rapid duplicate navigations for the same request
    final now = DateTime.now();
    if (_lastNavigatedRequestId == requestId &&
        _lastNavigatedAt != null &&
        now.difference(_lastNavigatedAt!) < const Duration(seconds: 5)) {
      return;
    }
    _lastNavigatedRequestId = requestId;
    _lastNavigatedAt = now;

    _container!.read(routerProvider).push('/rider/incoming-request/$requestId');
  }

  /// Rings and vibrates until the rider answers, like an incoming call.
  ///
  /// Vibration alone was too easy to miss on a bike, so this also loops the
  /// device's own ringtone. It plays on the ringer stream rather than the alarm
  /// one, so a rider who has silenced their phone stays silenced -- the
  /// vibration and the full-screen notification still get through.
  Future<void> startIncomingPickupAlert() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(
          pattern: _pickupVibrationPatternRaw,
          repeat: 0,
        );
      }
    } catch (_) {}

    try {
      await _ringtonePlayer.playRingtone(looping: true);
    } catch (_) {}

    // Both the tone and the buzzing stop themselves if nothing answers, so a
    // missed request can't ring out the battery.
    _vibrationTimeout?.cancel();
    _vibrationTimeout = Timer(
      _maxVibrationDuration,
      () => unawaited(stopIncomingPickupAlert()),
    );
  }

  Future<void> stopIncomingPickupAlert() async {
    _vibrationTimeout?.cancel();
    _vibrationTimeout = null;
    try {
      await Vibration.cancel();
    } catch (_) {}
    try {
      await _ringtonePlayer.stop();
    } catch (_) {}
  }

  // Dismisses the incoming pickup request notification
  Future<void> cancelIncomingPickupNotification(String requestId) async {
    try {
      await _localNotificationsPlugin.cancel(id: requestId.hashCode);
    } catch (_) {}
  }

  // Dismisses all pickup notifications
  Future<void> _cancelAllPickupNotifications() async {
    try {
      await _localNotificationsPlugin.cancelAll();
    } catch (_) {}
  }

  // Clean up push tokens and alerts on logout
  Future<void> handleLogout() async {
    _pendingRequestId = null;
    await stopIncomingPickupAlert();
    await _cancelAllPickupNotifications();
    await _setRiderPushEnabled(false);
    if (_isSignedInAsRider) {
      try {
        await _container!.read(riderRepositoryProvider).clearFcmToken();
      } catch (_) {}
    }
  }

  // Removes stale FCM device token from Supabase
  Future<void> _releaseStaleDeviceToken() async {
    final container = _container;
    if (container == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await container.read(riderRepositoryProvider).releaseDeviceFcmToken(token);
    } catch (_) {}
  }

  Future<void> _refreshAndSyncToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _syncToken(token);
  }

  Future<void> _syncToken(String token) async {
    final container = _container;
    if (container == null) return;
    if (container.read(currentUserRoleProvider) != UserRole.rider) return;
    await container.read(riderRepositoryProvider).updateFcmToken(token);
  }

  void dispose() {
    _vibrationTimeout?.cancel();
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
    _onTokenRefreshSub?.cancel();
    _authSub?.close();
  }
}
