import 'package:financafacil/core/services/device_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('mudar somente o minuto notifica a interface e persiste', () async {
    await DevicePreferences.load();
    var notifications = 0;
    void listener() => notifications++;
    DevicePreferences.time.addListener(listener);
    addTearDown(() => DevicePreferences.time.removeListener(listener));
    await DevicePreferences.setTime(const TimeOfDay(hour: 9, minute: 30));
    expect(notifications, 1);
    expect(DevicePreferences.time.value, const TimeOfDay(hour: 9, minute: 30));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('reminder_time'), '9:30');
  });
  test(
    'configuração inválida usa padrões em vez de valores antigos em memória',
    () async {
      await DevicePreferences.setTime(const TimeOfDay(hour: 18, minute: 15));
      SharedPreferences.setMockInitialValues({
        'reminder_time': '25:99',
        'theme_mode': 1,
      });
      await DevicePreferences.load();
      expect(DevicePreferences.time.value, const TimeOfDay(hour: 9, minute: 0));
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('theme_mode'), false);
    },
  );
  test('preserva a preferência antiga de hora ao carregar', () async {
    SharedPreferences.setMockInitialValues({'reminder_hour': 18});
    await DevicePreferences.load();
    expect(DevicePreferences.time.value, const TimeOfDay(hour: 18, minute: 0));
  });
}
