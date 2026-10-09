import 'package:financafacil/features/notifications/data/reminder_service.dart';
import 'package:financafacil/features/profile/data/profile_repository.dart';
import 'package:financafacil/features/profile/domain/user_profile.dart';
import 'package:financafacil/features/transactions/data/finance_repository.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:flutter/foundation.dart';

class FakeFinanceRepository implements FinanceRepository {
  List<FinanceEntry> entries = [];
  TransactionDraft? saved;
  Set<String>? paidIds;
  double? updatedAmount;
  String? deletedId;
  @override
  Future<void> deleteEntry(String id) async {
    deletedId = id;
    entries.removeWhere((entry) => entry.id == id);
  }
  @override
  Future<List<FinanceEntry>> transactions(DateTime through) async => entries;
  @override
  Future<List<FinanceCategory>> categories(TransactionKind kind) async =>
      const [FinanceCategory(id: '1', name: 'Categoria de teste')];
  @override
  Future<List<RecurrencePlan>> plans() async => [];
  @override
  Future<void> save(TransactionDraft draft) async {
    saved = draft;
  }

  @override
  Future<void> markPaid(Set<String> ids) async {
    paidIds = ids;
    entries = entries
        .map((entry) => FinanceEntry(
              id: entry.id,
              kind: entry.kind,
              amount: entry.amount,
              description: entry.description,
              dueDate: entry.dueDate,
              categoryName: entry.categoryName,
              isPaid: ids.contains(entry.id) || entry.isPaid,
              notes: entry.notes,
              isRecurring: entry.isRecurring,
              installment: entry.installment,
              totalInstallments: entry.totalInstallments,
              lastDue: entry.lastDue,
            ))
        .toList();
  }

  @override
  Future<void> markPending(Set<String> ids) async {
    entries = entries
        .map((e) => FinanceEntry(
            id: e.id,
            kind: e.kind,
            amount: e.amount,
            description: e.description,
            dueDate: e.dueDate,
            categoryName: e.categoryName,
            isPaid: ids.contains(e.id) ? false : e.isPaid,
            notes: e.notes,
            isRecurring: e.isRecurring,
            installment: e.installment,
            totalInstallments: e.totalInstallments,
            lastDue: e.lastDue))
        .toList();
  }

  @override
  Future<void> updateAmount(String id, double amount) async {
    updatedAmount = amount;
  }

  @override
  Future<void> stopPlan(String id) async {}
  @override
  Future<void> updateFutureAmount(String id, double amount) async {
    updatedAmount = amount;
  }
}

class FakeProfileRepository implements ProfileRepository {
  @override
  UserProfileData? currentProfile = const UserProfileData(
      name: 'Pietro', email: 'pietro@example.com', phone: '11999999999');
  @override
  Future<void> update(String name, String phone) async {
    currentProfile =
        UserProfileData(name: name, email: currentProfile!.email, phone: phone);
  }

  @override
  Future<void> signOut() async {
    currentProfile = null;
  }
}

class FakeReminderService implements ReminderService {
  @override
  final status = ValueNotifier(const ReminderStatus(
      enabled: true,
      message:
          'Lembretes preparados. Abra o app periodicamente para renovar os próximos vencimentos.'));
  @override
  final openRequested = ValueNotifier(false);
  List<FinanceEntry>? cached;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> activateOwner(String owner) async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> sync(String owner, List<FinanceEntry> entries) async {
    cached = entries;
  }

  @override
  Future<List<FinanceEntry>?> cachedEntries(String owner) async => cached;
  @override
  Future<void> clear() async {
    cached = null;
  }
}
