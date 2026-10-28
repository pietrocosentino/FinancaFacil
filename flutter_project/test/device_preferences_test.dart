import 'package:financafacil/core/services/device_biometrics.dart';
import 'package:financafacil/core/services/device_preferences.dart';
import 'package:financafacil/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_repositories.dart';

class _Biometrics implements BiometricAuthenticator {
  _Biometrics({this.available = true, this.authenticated = true});

  final bool available;
  final bool authenticated;
  String? reason;

  @override
  Future<bool> get canAuthenticate async => available;

  @override
  Future<bool> authenticate(String value) async {
    reason = value;
    return authenticated;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DevicePreferences.load();
  });
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

  testWidgets('biometria pode ser habilitada após confirmar identidade', (
    tester,
  ) async {
    final biometrics = _Biometrics();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: FakeProfileRepository(),
          biometrics: biometrics,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bloqueio biométrico'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Bloqueio biométrico'));
    await tester.pumpAndSettle();

    expect(DevicePreferences.biometricsEnabled.value, isTrue);
    expect(biometrics.reason, contains('ativar o bloqueio'));
    expect(find.text('Bloqueio biométrico ativado.'), findsOneWidget);
    await DevicePreferences.load();
    expect(DevicePreferences.biometricsEnabled.value, isTrue);
  });

  testWidgets('biometria não pode ser habilitada sem sensor configurado', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: FakeProfileRepository(),
          biometrics: _Biometrics(available: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bloqueio biométrico'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Bloqueio biométrico'));
    await tester.pumpAndSettle();

    expect(DevicePreferences.biometricsEnabled.value, isFalse);
    expect(
      find.text(
        'Configure uma biometria no aparelho antes de ativar o bloqueio.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancelar confirmação biométrica mantém bloqueio desativado', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          repository: FakeProfileRepository(),
          biometrics: _Biometrics(authenticated: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bloqueio biométrico'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Bloqueio biométrico'));
    await tester.pumpAndSettle();

    expect(DevicePreferences.biometricsEnabled.value, isFalse);
    expect(
      find.text('Biometria não confirmada. O bloqueio não foi ativado.'),
      findsOneWidget,
    );
  });
}
