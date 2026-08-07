import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:device_preview/device_preview.dart';
import 'core/config/router.dart';
import 'core/config/theme.dart';
import 'core/config/theme_provider.dart';
import 'core/services/paystack_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyCiXCzwhOVG97hb2zyE6Xw5-gHh7UUI0uU",
          appId: "1:718487738924:web:f81cdc6ef768fcec590f89",
          messagingSenderId: "718487738924",
          projectId: "cleanconnect-5a323",
          authDomain: "cleanconnect-5a323.firebaseapp.com",
          storageBucket: "cleanconnect-5a323.firebasestorage.app",
          measurementId: "G-HMD5MGE2N3",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  // Initialize Paystack SDK
  await PaystackService.instance.initialize();

  // Initialize Local Cache (Hive)
  await Hive.initFlutter();
  await Hive.openBox('auth_box');
  await Hive.openBox('settings_box');

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const ProviderScope(child: EcoWasteApp()),
    ),
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
      builder: (context, child) =>
          DevicePreview.appBuilder(context, SafeArea(child: child!)),
      theme: EcoTheme.lightTheme,
      darkTheme: EcoTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
