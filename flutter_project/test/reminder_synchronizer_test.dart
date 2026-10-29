import 'dart:async';

import 'package:financafacil/features/notifications/application/reminder_synchronizer.dart';
import 'package:financafacil/features/notifications/data/reminder_service.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';

class _CountingReminders extends FakeReminderService {
  final owners = <String>[];
  int syncs = 0;
  @override
  Future<void> activateOwner(String owner) async => owners.add(owner);
  @override
  Future<void> sync(String owner, List<FinanceEntry> entries) async {
    syncs++;
    await super.sync(owner, entries);
  }
}

void main() {
  test(
    'pedidos durante uma sincronização viram uma única nova rodada',
    () async {
      final reminders = _CountingReminders();
      final gates = <Completer<List<FinanceEntry>>>[];
      final synchronizer = ReminderSynchronizer(
        reminders: reminders,
        owner: 'owner',
        loadEntries: () {
          final gate = Completer<List<FinanceEntry>>();
          gates.add(gate);
          return gate.future;
        },
      );

      final first = synchronizer.run();
      await Future<void>.delayed(Duration.zero);
      synchronizer.run();
      synchronizer.run();
      synchronizer.run();
      expect(gates, hasLength(1));
      gates.single.complete(const []);
      await Future<void>.delayed(Duration.zero);
      expect(gates, hasLength(2));
      gates.last.complete(const []);
      await first;
      expect(reminders.syncs, 2);
      expect(reminders.owners, ['owner', 'owner']);
    },
  );

  test('falha ao carregar mantém o estado e informa o motivo', () async {
    final reminders = FakeReminderService();
    reminders.status.value = ReminderStatus(
      enabled: true,
      scheduledDays: 4,
      coveredUntil: DateTime(2026, 5, 20),
    );
    final synchronizer = ReminderSynchronizer(
      reminders: reminders,
      owner: 'owner',
      loadEntries: () async => throw StateError('sem conexão'),
    );
    await synchronizer.run();
    final status = reminders.status.value;
    expect(status.message, ReminderSynchronizer.failureMessage);
    expect(status.enabled, isTrue);
    expect(status.scheduledDays, 4);
    expect(status.coveredUntil, DateTime(2026, 5, 20));
    expect(reminders.cached, isNull);
  });

  test('após dispose não agenda nem altera o estado', () async {
    final reminders = _CountingReminders();
    final gate = Completer<List<FinanceEntry>>();
    final synchronizer = ReminderSynchronizer(
      reminders: reminders,
      owner: 'owner',
      loadEntries: () => gate.future,
    );
    final running = synchronizer.run();
    await Future<void>.delayed(Duration.zero);
    synchronizer.dispose();
    gate.complete(const []);
    await running;
    await synchronizer.run();
    expect(reminders.syncs, 0);
  });
}
