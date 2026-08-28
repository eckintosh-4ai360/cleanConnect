import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:device_preview/device_preview.dart';
import 'core/config/router.dart';
import 'core/config/theme.dart';
import 'core/config/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Firebase for push notifications (FCM)
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    firebaseReady = true;
  } catch (e) {
    debugPrint('!! PUSH DISABLED — Firebase failed to initialize: $e');
  }

  // Init Supabase
  try {
    await Supabase.initialize(
      url: 'https://mfysompctaxldphbxvkv.supabase.co',
      publishableKey: 'sb_publishable_BXemNj8edIkUZQ70h3LHvA_4Bl3iaan',
    );
  } catch (e) {
    debugPrint('Supabase initialization warning: $e');
  }

  // Local storage
  await Hive.initFlutter();
  await Hive.openBox('auth_box');
  await Hive.openBox('settings_box');

  // ProviderContainer for background notifications & top-level routing
  final container = ProviderContainer();
  if (firebaseReady) {
    try {
      await NotificationService.instance.initialize(container);
    } catch (e) {
      debugPrint('!! PUSH DISABLED — NotificationService failed to start: $e');
    }
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const EcoWasteApp()),
  );
}

class EcoWasteApp extends ConsumerWidget {
  const EcoWasteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CleanConnect',
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: (context, child) => DevicePreview.appBuilder(context, child!),
      theme: EcoTheme.lightTheme,
      darkTheme: EcoTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
