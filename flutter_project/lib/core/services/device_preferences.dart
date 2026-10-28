import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências deste aparelho; não alteram valores nem recorrências.
class DevicePreferences {
  static int _externalFlowCount = 0;
  static bool get externalFlowInProgress => _externalFlowCount > 0;

  static final time = ValueNotifier<TimeOfDay>(
    const TimeOfDay(hour: 9, minute: 0),
  );
  static final biometricsEnabled = ValueNotifier<bool>(false);

  static Future<void> setTime(TimeOfDay value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'reminder_time',
      '${value.hour}:${value.minute}',
    );
    time.value = value;
  }

  static Future<void> setBiometricsEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('biometrics_enabled', value);
    biometricsEnabled.value = value;
  }

  static Future<T> duringExternalFlow<T>(Future<T> Function() action) async {
    _externalFlowCount++;
    try {
      return await action();
    } finally {
      _externalFlowCount--;
    }
  }

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    biometricsEnabled.value =
        preferences.getBool('biometrics_enabled') ?? false;
    // Remove a preferência de tema substituída pela aparência padrão.
    await preferences.remove('theme_mode');
    final savedTime = preferences.getString('reminder_time')?.split(':');
    if (savedTime != null && savedTime.length == 2) {
      final hour = int.tryParse(savedTime[0]);
      final minute = int.tryParse(savedTime[1]);
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59) {
        time.value = TimeOfDay(hour: hour, minute: minute);
        return;
      }
    }

    final legacyHour = preferences.getInt('reminder_hour');
    time.value = TimeOfDay(
      hour: legacyHour != null && legacyHour >= 0 && legacyHour <= 23
          ? legacyHour
          : 9,
      minute: 0,
    );
    if (legacyHour != null) {
      await setTime(time.value);
      await preferences.remove('reminder_hour');
    }
  }
}
