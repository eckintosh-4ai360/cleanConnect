import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/rider/presentation/providers/rider_providers.dart';
import '../../firebase_options.dart';
import '../config/router.dart';

const String pickupRequestsChannelId = 'pickup_requests_channel';
const String pickupRequestsChannelName = 'New Pickup Requests';
const List<int> _pickupVibrationPatternRaw = [0, 1000, 500, 1000, 500, 1000];

final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Must be a top-level function (and annotated `vm:entry-point`) so the
/// Android FCM background isolate can find and invoke it when a data message
/// arrives while the app is backgrounded or fully killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (message.data['type'] != 'new_pickup_request') return;
  // This is a fresh isolate: the plugin instance here has never been
  // initialized, and the channel may not exist yet, so `show` would be
  // dropped without this.
  await _ensureLocalNotifications();
  await _showIncomingPickupNotification(message.data);
}

/// Idempotent per-isolate setup of the local-notifications plugin and the
/// high-importance pickup channel. [onTap] is only wired in the main isolate —
/// taps on a notification posted from the background isolate are delivered to
/// the main isolate at launch via `getNotificationAppLaunchDetails`.
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

/// Orchestrates FCM + local notifications + vibration for the "incoming
/// pickup request" rider alert. Initialized once in `main()` with the app's
/// root [ProviderContainer] so it can read/navigate outside the widget tree
/// (needed for background/terminated notification taps).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  ProviderContainer? _container;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  ProviderSubscription<AuthState>? _authSub;
  String? _lastNavigatedRequestId;
  DateTime? _lastNavigatedAt;

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
      (previous, next) {
        if (next is AuthAuthenticated && next.user.role == UserRole.rider) {
          unawaited(_refreshAndSyncToken());
        }
      },
      fireImmediately: true,
    );

    // Cold start via a data-message tap (app was fully terminated).
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null &&
        initialMessage.data['type'] == 'new_pickup_request') {
      _navigateToRequestId(initialMessage.data['requestId'] as String?);
    }

    // Cold start via tapping the local full-screen-intent notification.
    final launchDetails =
        await _localNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _navigateToRequestId(launchDetails?.notificationResponse?.payload);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (message.data['type'] != 'new_pickup_request') return;
    unawaited(startVibrationLoop());
    _navigateToRequestId(message.data['requestId'] as String?);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    if (message.data['type'] != 'new_pickup_request') return;
    _navigateToRequestId(message.data['requestId'] as String?);
  }

  void _navigateToRequestId(String? requestId) {
    if (requestId == null || requestId.isEmpty || _container == null) return;

    // The same request can legitimately trigger onMessage + a notification
    // tap in quick succession — avoid pushing the same screen twice.
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

  Future<void> startVibrationLoop() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(
          pattern: _pickupVibrationPatternRaw,
          repeat: 0,
        );
      }
    } catch (_) {
      // Vibration is a nice-to-have; devices without it shouldn't crash.
    }
  }

  Future<void> stopVibration() async {
    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  /// Dismisses the incoming-request tray notification. Posted with
  /// `ongoing: true, autoCancel: false` so a stray tap can't lose the
  /// request before the rider decides — must be cancelled explicitly once
  /// accept/decline resolves it, or it lingers in the shade.
  Future<void> cancelIncomingPickupNotification(String requestId) async {
    try {
      await _localNotificationsPlugin.cancel(id: requestId.hashCode);
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
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
    _onTokenRefreshSub?.cancel();
    _authSub?.close();
  }
}
