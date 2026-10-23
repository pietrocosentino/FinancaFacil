import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências deste aparelho (horário dos lembretes); não alteram valores
/// nem recorrências. A aparência é fixa, com a identidade visual do app.
class DevicePreferences {
  static final time = ValueNotifier<TimeOfDay>(
    const TimeOfDay(hour: 9, minute: 0),
  );

  static Future<void> setTime(TimeOfDay value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'reminder_time',
      '${value.hour}:${value.minute}',
    );
    time.value = value;
  }

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    // Escolha de tema de versões anteriores deixa de valer.
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
  }
}
