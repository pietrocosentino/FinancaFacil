import 'package:financafacil/core/services/reminder_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('mudar somente o minuto notifica a interface e persiste', () async {
    await ReminderPreferences.load();
    var notifications = 0;
    void listener() => notifications++;
    ReminderPreferences.time.addListener(listener);
    addTearDown(() => ReminderPreferences.time.removeListener(listener));
    await ReminderPreferences.setTime(const TimeOfDay(hour: 9, minute: 30));
    expect(notifications, 1);
    expect(
        ReminderPreferences.time.value, const TimeOfDay(hour: 9, minute: 30));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('reminder_time'), '9:30');
  });
  test('configuração inválida usa padrões em vez de valores antigos em memória',
      () async {
    await ReminderPreferences.setTime(const TimeOfDay(hour: 18, minute: 15));
    await ReminderPreferences.setTheme(ThemeMode.light);
    SharedPreferences.setMockInitialValues(
        {'reminder_time': '25:99', 'theme_mode': -1});
    await ReminderPreferences.load();
    expect(ReminderPreferences.time.value, const TimeOfDay(hour: 9, minute: 0));
    expect(ReminderPreferences.themeMode.value, ThemeMode.dark);
  });
  test('preserva a preferência antiga de hora ao carregar', () async {
    SharedPreferences.setMockInitialValues({'reminder_hour': 18});
    await ReminderPreferences.load();
    expect(
        ReminderPreferences.time.value, const TimeOfDay(hour: 18, minute: 0));
  });
}
