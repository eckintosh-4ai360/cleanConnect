import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/rider/presentation/providers/rider_providers.dart';
import '../../firebase_options.dart';
import '../config/router.dart';

const String pickupRequestsChannelId = 'pickup_requests_channel';
const String pickupRequestsChannelName = 'New Pickup Requests';
const List<int> _pickupVibrationPatternRaw = [0, 1000, 500, 1000, 500, 1000];

const String _riderPushEnabledKey = 'rider_push_alerts_enabled';

/// Deliberately not Hive, which the rest of the app uses for local state: a
/// Hive box takes an exclusive lock, so the background isolate could not open
/// `settings_box` while the main isolate holds it — exactly the moment this
/// flag has to be readable. SharedPreferences is backed by platform storage
/// that both isolates can read.
final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Whether this device is currently signed in as a rider, as last recorded by
/// the main isolate in [_setRiderPushEnabled].
///
/// An FCM token belongs to the *device*, not to the account that registered
/// it, and `notify-riders-on-new-pickup` fans out to every token stored on the
/// `riders` table. So a device where a rider once signed in keeps receiving
/// pickup alerts after somebody else signs in — and the background isolate has
/// no auth state of its own to check, hence this flag.
///
/// Defaults to `true`: a rider who has not opened the app since this flag was
/// introduced must keep getting alerts. It only suppresses once the main
/// isolate has positively seen a non-rider session.
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
  } catch (_) {
    // Losing the flag only costs us the background-isolate guard; the
    // foreground role check in NotificationService still holds.
  }
}

/// Must be a top-level function (and annotated `vm:entry-point`) so the
/// Android FCM background isolate can find and invoke it when a data message
/// arrives while the app is backgrounded or fully killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (message.data['type'] != 'new_pickup_request') return;
  // Not a rider on this device any more — showing the alert would post an
  // ongoing, full-screen, vibrating notification to somebody who cannot act on
  // it and cannot swipe it away either.
  if (!await _riderPushEnabled()) return;
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

  /// Hard ceiling on the alert vibration. The incoming-request screen stops it
  /// on dispose, but that screen does not always get to mount — a router role
  /// redirect, a push that lands on the wrong account, a request that is
  /// already gone — and `repeat: 0` runs until something cancels it. So it
  /// cancels itself too, and can never outlive the alert it belongs to.
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

  /// Keeps this device's push registration in step with who is actually signed
  /// in on it. Riders get their token (re)published; everybody else gets the
  /// device detached from the fan-out and any in-flight rider alert killed.
  Future<void> _handleAuthStateChange(AuthState state) async {
    // Startup: the Supabase session has not been read back yet, so we cannot
    // tell a rider from a customer. Decide nothing until it resolves.
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

    // A non-rider session on a device that may still be registered as some
    // rider's: silence whatever is already running and drop the registration
    // so the next pickup does not reach us at all.
    _pendingRequestId = null;
    await stopVibration();
    await _cancelAllPickupNotifications();
    if (state is AuthAuthenticated) {
      await _releaseStaleDeviceToken();
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (message.data['type'] != 'new_pickup_request') return;
    if (!_isSignedInAsRider) {
      // A rider token this device never gave up. Do not vibrate, do not
      // navigate — just make sure it stops arriving.
      unawaited(_releaseStaleDeviceToken());
      return;
    }
    unawaited(startVibrationLoop());
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
      // Cold start: auth is still resolving (or nobody is signed in). Hold the
      // request — _handleAuthStateChange dispatches or drops it once we know
      // who this is. Navigating now would only bounce off the router's
      // rider-route guard and strand the alert.
      _pendingRequestId = requestId;
      return;
    }
    // The incoming-request screen lives under /rider/, which the router
    // redirects away from for anybody else — so the screen that stops the
    // vibration and clears the notification would never mount.
    if (role != UserRole.rider) return;

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
        _vibrationTimeout?.cancel();
        _vibrationTimeout = Timer(
          _maxVibrationDuration,
          () => unawaited(stopVibration()),
        );
      }
    } catch (_) {
      // Vibration is a nice-to-have; devices without it shouldn't crash.
    }
  }

  Future<void> stopVibration() async {
    _vibrationTimeout?.cancel();
    _vibrationTimeout = null;
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

  /// Clears every pickup alert in the shade. Used when we cannot enumerate the
  /// request ids (they were posted from the background isolate) but know none
  /// of them are actionable — pickup alerts are the only notifications this
  /// app posts.
  Future<void> _cancelAllPickupNotifications() async {
    try {
      await _localNotificationsPlugin.cancelAll();
    } catch (_) {}
  }

  /// Called just before sign-out, while the session is still valid enough for
  /// RLS to allow the write. A token left behind here is exactly what makes
  /// the *next* person on this device get rider alerts they cannot dismiss.
  Future<void> handleLogout() async {
    _pendingRequestId = null;
    await stopVibration();
    await _cancelAllPickupNotifications();
    await _setRiderPushEnabled(false);
    if (_isSignedInAsRider) {
      try {
        await _container!.read(riderRepositoryProvider).clearFcmToken();
      } catch (_) {
        // Best effort — _releaseStaleDeviceToken covers what this misses.
      }
    }
  }

  /// Detaches this device's token from whichever rider is still holding it —
  /// the repair path for a session that ended without [handleLogout] running
  /// (app killed mid-logout, or a token registered before this fix shipped).
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
