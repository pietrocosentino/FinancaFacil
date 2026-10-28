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
  test('persiste horário selecionado e migra a preferência antiga', () async {
    await DevicePreferences.setTime(const TimeOfDay(hour: 18, minute: 30));
    expect(DevicePreferences.time.value, const TimeOfDay(hour: 18, minute: 30));
    final saved = await SharedPreferences.getInstance();
    expect(saved.getString('reminder_time'), '18:30');

    SharedPreferences.setMockInitialValues({
      'reminder_hour': 7,
      'theme_mode': 1,
    });
    await DevicePreferences.load();
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('reminder_time'), '7:0');
    expect(preferences.containsKey('reminder_hour'), false);
    expect(preferences.containsKey('theme_mode'), false);
    expect(DevicePreferences.time.value, const TimeOfDay(hour: 7, minute: 0));
  });

  test('horário inválido retorna ao padrão de 9h', () async {
    SharedPreferences.setMockInitialValues({'reminder_time': '25:99'});
    await DevicePreferences.load();
    expect(DevicePreferences.time.value, const TimeOfDay(hour: 9, minute: 0));
  });

  test('fluxo externo restaura o estado mesmo quando falha', () async {
    expect(DevicePreferences.externalFlowInProgress, isFalse);
    await expectLater(
      DevicePreferences.duringExternalFlow(() async {
        expect(DevicePreferences.externalFlowInProgress, isTrue);
        throw StateError('cancelado');
      }),
      throwsStateError,
    );
    expect(DevicePreferences.externalFlowInProgress, isFalse);
  });

  testWidgets('seletor de lembretes permite escolher hora e minuto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(repository: FakeProfileRepository())),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Horário dos lembretes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Horário dos lembretes'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2));
    expect(
      find.text('Escolha a hora e os minutos do aviso diário.'),
      findsOneWidget,
    );
    expect(find.text('Salvar'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('05').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('03').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(DevicePreferences.time.value, const TimeOfDay(hour: 5, minute: 3));
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
