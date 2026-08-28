import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_provider.g.dart';

@riverpod
class OnboardingController extends _$OnboardingController {
  static const String _key = 'has_completed_onboarding';

  @override
  bool build() {
    if (!Hive.isBoxOpen('settings_box')) {
      return false;
    }
    final box = Hive.box('settings_box');
    return box.get(_key, defaultValue: false) as bool;
  }

  void completeOnboarding() {
    if (Hive.isBoxOpen('settings_box')) {
      final box = Hive.box('settings_box');
      box.put(_key, true);
    }
    state = true;
  }
}
