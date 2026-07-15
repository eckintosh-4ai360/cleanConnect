import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_provider.g.dart';

@riverpod
class ThemeModeController extends _$ThemeModeController {
  static const String _key = 'theme_mode';

  @override
  ThemeMode build() {
    final box = Hive.box('settings_box');
    final saved = box.get(_key, defaultValue: 'light') as String;
    return saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme() {
    final box = Hive.box('settings_box');
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
      box.put(_key, 'light');
    } else {
      state = ThemeMode.dark;
      box.put(_key, 'dark');
    }
  }

  bool get isDark => state == ThemeMode.dark;
}
