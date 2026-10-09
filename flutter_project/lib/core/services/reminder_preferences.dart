import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências do aparelho; não alteram os valores ou as recorrências.
class ReminderPreferences {
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  static final time =
      ValueNotifier<TimeOfDay>(const TimeOfDay(hour: 9, minute: 0));

  static Future<void> setTheme(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('theme_mode', mode.index);
    themeMode.value = mode;
  }

  static Future<void> setTime(TimeOfDay value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        'reminder_time', '${value.hour}:${value.minute}');
    time.value = value;
  }

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final theme = preferences.getInt('theme_mode');
    themeMode.value =
        theme != null && theme >= 0 && theme < ThemeMode.values.length
            ? ThemeMode.values[theme]
            : ThemeMode.light;
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
        minute: 0);
  }
}
