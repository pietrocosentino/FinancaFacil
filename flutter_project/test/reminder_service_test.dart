import 'package:financafacil/features/notifications/data/reminder_service.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications =
      MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');
  final calls = <MethodCall>[];
  var enabled = false;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    enabled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, (_) async => 'America/Sao_Paulo');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'getNotificationAppLaunchDetails':
          return {'notificationLaunchedApp': true};
        case 'areNotificationsEnabled':
          return enabled;
        case 'requestNotificationsPermission':
          enabled = true;
          return true;
        default:
          return null;
      }
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, null);
  });
  FinanceEntry entry({bool paid = false}) => FinanceEntry(
      id: 'optical',
      kind: TransactionKind.expense,
      amount: 90.60,
      description: 'Ótica',
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      categoryName: 'Saúde',
      isPaid: paid,
      notes: 'Transferir para meu pai');

  test('permissão é explícita e abertura por notificação não confirma conta',
      () async {
    final service = LocalReminderService();
    await service.initialize();
    await service.activateOwner('owner');
    await service.sync('owner', [entry()]);
    expect(service.openRequested.value, true);
    expect(
        calls.where((call) => call.method == 'requestNotificationsPermission'),
        isEmpty);
    expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
    expect((await service.cachedEntries('owner'))!.single.isPaid, false);
    await service.requestPermission();
    await service.sync('owner', [entry()]);
    expect(calls.where((call) => call.method == 'zonedSchedule').length, 60);
    final arguments = calls
        .firstWhere((call) => call.method == 'zonedSchedule')
        .arguments as Map;
    expect(arguments['payload'], 'notifications');
    expect((arguments['platformSpecifics'] as Map)['actions'],
        anyOf(isNull, isEmpty));
    expect(service.status.value.scheduledDays, 60);
  });
  test('confirmar limpa agenda e sair remove dados e pedidos de abertura',
      () async {
    enabled = true;
    final service = LocalReminderService();
    await service.initialize();
    await service.activateOwner('owner');
    await service.sync('owner', [entry()]);
    await service.sync('owner', [entry(paid: true)]);
    expect(service.status.value.scheduledDays, 0);
    expect((await service.cachedEntries('owner'))!.single.isPaid, true);
    expect(await service.cachedEntries('another-owner'), isNull);
    await service.clear();
    expect(await service.cachedEntries('owner'), isNull);
    expect(service.openRequested.value, false);
    expect(calls.last.method, 'cancelAll');
  });
  test(
      'trocar conta remove snapshot e rejeita sincronização do usuário anterior',
      () async {
    enabled = true;
    final service = LocalReminderService();
    await service.initialize();
    await service.activateOwner('one');
    await service.sync('one', [entry()]);
    await service.activateOwner('two');
    final scheduled =
        calls.where((call) => call.method == 'zonedSchedule').length;
    await service.sync('one', [entry()]);
    expect(await service.cachedEntries('one'), isNull);
    expect(calls.where((call) => call.method == 'zonedSchedule').length,
        scheduled);
  });
  test('snapshot corrompido é descartado sem derrubar a consulta offline',
      () async {
    final service = LocalReminderService();
    await service.initialize();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('financafacil.reminder_snapshot',
        '{"owner":"owner","entries":"invalid"}');
    expect(await service.cachedEntries('owner'), isNull);
    expect(preferences.getString('financafacil.reminder_snapshot'), isNull);
  });
}
