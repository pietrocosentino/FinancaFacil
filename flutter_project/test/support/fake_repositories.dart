import 'package:financafacil/core/utils/finance_updates.dart';
import 'package:financafacil/features/notifications/data/reminder_service.dart';
import 'package:financafacil/features/profile/data/profile_repository.dart';
import 'package:financafacil/features/profile/domain/user_profile.dart';
import 'package:financafacil/features/transactions/data/finance_repository.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:flutter/foundation.dart';

/// Repositório em memória. Assim como o adapter Supabase, avisa as telas por
/// `notifyFinanceChanged` depois de cada alteração.
class FakeFinanceRepository implements FinanceRepository {
  List<FinanceEntry> entries = [];
  TransactionDraft? saved;
  Set<String>? paidIds;
  double? updatedAmount;
  String? deletedId;
  String? stoppedPlanId;

  @override
  Future<List<FinanceEntry>> transactions(DateTime through) async => entries;
  @override
  Future<List<FinanceCategory>> categories(TransactionKind kind) async => [
    const FinanceCategory(id: '1', name: 'Categoria de teste'),
    ...createdCategories,
  ];
  @override
  Future<List<RecurrencePlan>> plans() async => [];

  @override
  Future<void> save(TransactionDraft draft) async {
    saved = draft;
    notifyFinanceChanged();
  }

  @override
  Future<void> markPaid(Set<String> ids) async {
    paidIds = ids;
    _setPaid(ids, true);
  }

  void _setPaid(Set<String> ids, bool paid) {
    entries = [
      for (final entry in entries)
        ids.contains(entry.id) ? entry.copyWith(isPaid: paid) : entry,
    ];
    notifyFinanceChanged();
  }

  EntryDetails? updatedDetails;
  IncomeRuleDetails? updatedIncomeRule;
  final inactiveChanges = <String, bool>{};

  @override
  Future<void> updateDetails(String id, EntryDetails details) async {
    updatedDetails = details;
    notifyFinanceChanged();
  }

  @override
  Future<void> updateIncomeRule(
    String ruleId,
    IncomeRuleDetails details,
  ) async {
    updatedIncomeRule = details;
    notifyFinanceChanged();
  }

  @override
  Future<void> setInactive(String id, bool inactive) async {
    inactiveChanges[id] = inactive;
    entries = [
      for (final entry in entries)
        entry.id == id ? entry.copyWith(isInactive: inactive) : entry,
    ];
    notifyFinanceChanged();
  }

  @override
  Future<void> updateAmount(String id, double amount) async {
    updatedAmount = amount;
    notifyFinanceChanged();
  }

  @override
  Future<void> updateFutureAmount(String id, double amount) async {
    updatedAmount = amount;
    notifyFinanceChanged();
  }

  @override
  Future<void> stopPlan(String id) async {
    stoppedPlanId = id;
    notifyFinanceChanged();
  }

  final createdCategories = <FinanceCategory>[];
  final notReceivedIds = <String>[];

  @override
  Future<FinanceCategory> createCategory(
    TransactionKind kind,
    String name,
  ) async {
    final category = FinanceCategory(
      id: 'new-${name.trim()}',
      name: name.trim(),
    );
    createdCategories.add(category);
    notifyFinanceChanged();
    return category;
  }

  @override
  Future<void> markNotReceived(String id) async {
    notReceivedIds.add(id);
    entries = [
      for (final entry in entries)
        entry.id == id
            ? FinanceEntry.fromMap({
                ...entry.toMap(),
                'is_paid': false,
                '_manual_receipt': true,
              })
            : entry,
    ];
    notifyFinanceChanged();
  }

  @override
  Future<void> deleteEntry(String id) async {
    deletedId = id;
    entries.removeWhere((entry) => entry.id == id);
    notifyFinanceChanged();
  }
}

class FakeProfileRepository implements ProfileRepository {
  @override
  UserProfileData? currentProfile = const UserProfileData(
    name: 'Pietro',
    email: 'pietro@example.com',
    phone: '11999999999',
  );
  @override
  Future<void> update(String name, String phone) async {
    currentProfile = UserProfileData(
      name: name,
      email: currentProfile!.email,
      phone: phone,
    );
  }

  @override
  Future<void> signOut() async {
    currentProfile = null;
  }
}

class FakeReminderService implements ReminderService {
  @override
  final status = ValueNotifier(
    const ReminderStatus(
      enabled: true,
      message: 'Lembretes preparados. Abra o app periodicamente para renovar os próximos vencimentos.',
    ),
  );
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
