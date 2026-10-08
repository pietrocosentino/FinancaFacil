import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/app_services.dart';
import '../../core/utils/finance_updates.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/notifications/data/reminder_service.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/transactions/data/finance_repository.dart';
import '../../features/transactions/presentation/screens/add_transaction_screen.dart';
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
  final _navigator = GlobalKey<NavigatorState>();
  final _addKey = GlobalKey<AddTransactionScreenState>();
  final _tab = ValueNotifier<int>(0);
  late final List<Widget> _screens;
  @override
  void initState() {
    super.initState();
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
          repository: widget.financeRepository,
          reminders: _reminders,
          onNavigateToAdd: _add,
          onNavigateToNotifications: _openNotifications),
      TransactionsListScreen(
          repository: widget.financeRepository,
          addKey: _addKey,
          onEnableReminders: _openNotifications),
      ProfileScreen(
          repository: widget.profileRepository,
          onNavigateToNotifications: _openNotifications),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    financeRevision.removeListener(_syncReminders);
    _reminders?.openRequested.removeListener(_notificationTapped);
    _tab.dispose();
    super.dispose();
  }

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

  Future<void> _add() async {
    if (_adding || !mounted) return;
    _adding = true;
    try {
      await _navigator.currentState?.push(MaterialPageRoute(
          builder: (_) => AddTransactionScreen(
              key: _addKey,
              repository: widget.financeRepository,
              onEnableReminders: _openNotifications)));
    } finally {
      _adding = false;
    }
  }

  @override
  Widget build(BuildContext context) => NavigatorPopHandler(
        onPop: () => _navigator.currentState?.maybePop(),
        child: Scaffold(
          body: Navigator(
              key: _navigator,
              onGenerateRoute: (settings) => MaterialPageRoute(
                    settings: settings,
                    builder: (_) => ValueListenableBuilder<int>(
                        valueListenable: _tab,
                        builder: (_, index, __) =>
                            IndexedStack(index: index, children: _screens)),
                  )),
          bottomNavigationBar: ValueListenableBuilder<int>(
              valueListenable: _tab,
              builder: (_, index, __) => BottomNavigationBar(
                    currentIndex: index,
                    onTap: _onTabTapped,
                    items: const [
                      BottomNavigationBarItem(
                          icon: Icon(Icons.home_outlined),
                          activeIcon: Icon(Icons.home),
                          label: 'Início'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.receipt_long_outlined),
                          activeIcon: Icon(Icons.receipt_long),
                          label: 'Finanças'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.person_outline),
                          activeIcon: Icon(Icons.person),
                          label: 'Perfil'),
                    ],
                  )),
        ),
      );
}
