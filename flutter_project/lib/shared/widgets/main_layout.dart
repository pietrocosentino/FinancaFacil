import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/app_services.dart';
import '../../core/utils/finance_updates.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/imports/presentation/import_screen.dart';
import '../../features/notifications/data/reminder_service.dart';
import '../../features/notifications/domain/reminder_plan.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/profile_controller.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/widgets/profile_identity.dart';
import '../../features/transactions/data/finance_repository.dart';
import '../../features/transactions/domain/finance_models.dart';
import '../../features/transactions/presentation/screens/add_transaction_screen.dart';
import '../../features/transactions/presentation/screens/finance_registration_screen.dart';
import '../../features/transactions/presentation/screens/transactions_list_screen.dart';

/// As rotas internas ficam dentro do corpo; o menu permanece fora delas.
class MainLayout extends StatefulWidget {
  const MainLayout(
      {super.key,
      this.financeRepository,
      this.profileRepository,
      this.reminderService,
      this.userId});
  final FinanceRepository? financeRepository;
  final ProfileRepository? profileRepository;
  final ReminderService? reminderService;
  final String? userId;
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  ReminderService? _reminders;
  bool _syncing = false;
  bool _syncAgain = false;
  bool _notificationsOpen = false;
  bool _adding = false;
  bool _profileOpen = false;
  final _navigator = GlobalKey<NavigatorState>();
  final _addKey = GlobalKey<AddTransactionScreenState>();
  final _tab = ValueNotifier<int>(0);
  late final List<Widget> _screens;
  late final ProfileController _profile;
  late Future<List<FinanceEntry>> _headerEntries;
  @override
  void initState() {
    super.initState();
    _profile =
        ProfileController(widget.profileRepository ?? AppServices.profile);
    _profile.loadPhoto();
    _headerEntries = (widget.financeRepository ?? AppServices.finance)
        .transactions(DateTime.now().add(const Duration(days: 3)));
    financeRevision.addListener(_reloadHeader);
    _reminders = widget.reminderService ??
        (widget.financeRepository == null ? AppServices.reminders : null);
    WidgetsBinding.instance.addObserver(this);
    financeRevision.addListener(_syncReminders);
    _reminders?.openRequested.addListener(_notificationTapped);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncReminders();
      _notificationTapped();
    });
    _screens = [
      DashboardScreen(
          showHeader: false,
          repository: widget.financeRepository,
          reminders: _reminders,
          onNavigateToAdd: _add,
          onNavigateToNotifications: _openNotifications),
      FinanceRegistrationScreen(
          onAddExpense: () => _add(),
          onAddIncome: () => _add(kind: TransactionKind.income),
          onImport: () => _navigator.currentState?.push(MaterialPageRoute(
              builder: (_) =>
                  ImportScreen(finance: widget.financeRepository)))),
      TransactionsListScreen(
          showRegistration: false,
          repository: widget.financeRepository,
          addKey: _addKey,
          onEnableReminders: _openNotifications),
      ProfileScreen(
          controller: _profile,
          showIdentity: false,
          repository: widget.profileRepository,
          onNavigateToNotifications: _openNotifications),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    financeRevision.removeListener(_syncReminders);
    _reminders?.openRequested.removeListener(_notificationTapped);
    financeRevision.removeListener(_reloadHeader);
    _profile.dispose();
    _tab.dispose();
    super.dispose();
  }

  void _reloadHeader() {
    if (!mounted) return;
    final future = (widget.financeRepository ?? AppServices.finance)
        .transactions(DateTime.now().add(const Duration(days: 3)));
    setState(() {
      _headerEntries = future;
    });
  }

  Future<void> _openProfile() async {
    if (_profileOpen || !mounted) return;
    _profileOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.78,
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(
                controller: _profile,
                showIdentity: false,
                onClose: () => Navigator.of(sheetContext).pop(),
                onNavigateToNotifications: () {
                  Navigator.of(sheetContext).pop();
                  _openNotifications();
                },
              ),
            ),
          ),
        ),
      );
    } finally {
      _profileOpen = false;
    }
  }

  Widget _header() => SafeArea(
      bottom: false,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Expanded(
                child:
                    ProfileIdentity(controller: _profile, onTap: _openProfile)),
            const SizedBox(width: 8),
            Tooltip(
                message: 'FinançaFácil',
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset('assets/icon/icon.png',
                      width: 24, height: 24, cacheWidth: 48),
                  const SizedBox(height: 2),
                  Text('FinançaFácil',
                      style: Theme.of(context).textTheme.labelMedium),
                ])),
            FutureBuilder<List<FinanceEntry>>(
                future: _headerEntries,
                builder: (_, snapshot) {
                  final count =
                      pendingBills(snapshot.data ?? [], DateTime.now()).length;
                  return IconButton(
                      tooltip: 'Notificações',
                      onPressed: _openNotifications,
                      icon: Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          child: const Icon(Icons.notifications_outlined)));
                }),
          ])));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) notifyFinanceChanged();
  }

  void _notificationTapped() {
    if (!mounted || _reminders?.openRequested.value != true) return;
    _reminders!.openRequested.value = false;
    _openNotifications();
  }

  Future<void> _openNotifications() async {
    if (_notificationsOpen || !mounted) return;
    _notificationsOpen = true;
    try {
      await _navigator.currentState?.push(MaterialPageRoute(
          builder: (_) => NotificationsScreen(
                repository: widget.financeRepository ?? AppServices.finance,
                reminders: _reminders,
                owner: widget.userId,
              )));
    } finally {
      _notificationsOpen = false;
    }
  }

  Future<void> _syncReminders() async {
    final reminders = _reminders;
    final owner = widget.userId;
    if (reminders == null || owner == null || !mounted) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    do {
      _syncAgain = false;
      try {
        await reminders.activateOwner(owner);
        final entries = await (widget.financeRepository ?? AppServices.finance)
            .transactions(DateTime.now().add(const Duration(days: 90)));
        if (mounted) await reminders.sync(owner, entries);
      } catch (_) {
        if (mounted) {
          final previous = reminders.status.value;
          reminders.status.value = ReminderStatus(
              enabled: previous.enabled,
              coveredUntil: previous.coveredUntil,
              scheduledDays: previous.scheduledDays,
              message:
                  'Não foi possível atualizar os lembretes. Confira a conexão e as permissões do aparelho.');
        }
      }
    } while (_syncAgain && mounted);
    _syncing = false;
  }

  Future<void> _onTabTapped(int index) async {
    final add = _addKey.currentState;
    if (add != null && !await add.requestLeave()) return;
    if (!mounted) return;
    _navigator.currentState?.popUntil((route) => route.isFirst);
    _tab.value = index;
  }

  Future<void> _add({TransactionKind kind = TransactionKind.expense}) async {
    if (_adding || !mounted) return;
    _adding = true;
    try {
      await _navigator.currentState?.push(MaterialPageRoute(
          builder: (_) => AddTransactionScreen(
              key: _addKey,
              initialKind: kind,
              repository: widget.financeRepository,
              onEnableReminders: _openNotifications)));
    } finally {
      _adding = false;
    }
  }

  @override
  Widget build(BuildContext context) => NavigatorPopHandler(
        onPopWithResult: (result) => _navigator.currentState?.maybePop(result),
        child: Scaffold(
          body: Column(children: [
            _header(),
            Expanded(
              child: Navigator(
                  key: _navigator,
                  onGenerateRoute: (settings) => MaterialPageRoute(
                        settings: settings,
                        builder: (_) => ValueListenableBuilder<int>(
                            valueListenable: _tab,
                            builder: (_, index, __) =>
                                IndexedStack(index: index, children: _screens)),
                      )),
            ),
          ]),
          bottomNavigationBar: ValueListenableBuilder<int>(
              valueListenable: _tab,
              builder: (_, index, __) => BottomNavigationBar(
                    type: BottomNavigationBarType.fixed,
                    currentIndex: index,
                    onTap: _onTabTapped,
                    items: const [
                      BottomNavigationBarItem(
                          icon: Icon(Icons.home_outlined),
                          activeIcon: Icon(Icons.home),
                          label: 'Início'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.add_circle_outline),
                          activeIcon: Icon(Icons.add_circle),
                          label: 'Finanças'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.receipt_long_outlined),
                          activeIcon: Icon(Icons.receipt_long),
                          label: 'Extrato'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.person_outline),
                          activeIcon: Icon(Icons.person),
                          label: 'Perfil'),
                    ],
                  )),
        ),
      );
}
