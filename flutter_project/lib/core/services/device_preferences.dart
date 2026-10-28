import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências deste aparelho; não alteram valores nem recorrências.
class DevicePreferences {
  static final biometricsEnabled = ValueNotifier<bool>(false);

  static Future<void> setBiometricsEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('biometrics_enabled', value);
    biometricsEnabled.value = value;
  }

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    biometricsEnabled.value =
        preferences.getBool('biometrics_enabled') ?? false;
    // Remove preferências substituídas por horário fixo e aparência padrão.
    await preferences.remove('theme_mode');
    await preferences.remove('reminder_time');
    await preferences.remove('reminder_hour');
  }
}
