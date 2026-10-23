import 'package:flutter/material.dart';

import '../../core/services/app_services.dart';
import '../../core/services/reminder_preferences.dart';
import '../../core/utils/finance_updates.dart';
import '../../core/utils/single_flight.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/imports/data/import_repository.dart';
import '../../features/imports/presentation/import_screen.dart';
import '../../features/notifications/application/reminder_synchronizer.dart';
import '../../features/notifications/data/reminder_service.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/profile_controller.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/transactions/data/finance_repository.dart';
import '../../features/transactions/domain/finance_models.dart';
import '../../features/transactions/presentation/screens/add_transaction_screen.dart';
import '../../features/transactions/presentation/screens/finance_registration_screen.dart';
import '../../features/transactions/presentation/screens/transactions_list_screen.dart';
import 'main_header.dart';

/// Raiz da área autenticada e ponto de composição das dependências das telas.
///
/// As rotas internas ficam dentro do corpo; o cabeçalho e o menu permanecem
/// fora delas. Repositórios omitidos usam as implementações de produção.
class MainLayout extends StatefulWidget {
  const MainLayout({
    super.key,
    this.financeRepository,
    this.profileRepository,
    this.importRepository,
    this.reminderService,
    this.userId,
  });
  final FinanceRepository? financeRepository;
  final ProfileRepository? profileRepository;
  final ImportRepository? importRepository;
  final ReminderService? reminderService;
  final String? userId;
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  /// Pendências exibidas no sino: atrasadas e próximas do vencimento.
  static const _headerHorizon = Duration(days: 3);

  /// Período coberto pelos lembretes agendados no aparelho.
  static const _remindersHorizon = Duration(days: 90);

  late final FinanceRepository _finance;
  late final ProfileController _profile;
  ReminderService? _reminders;
  ReminderSynchronizer? _synchronizer;
  final _navigator = GlobalKey<NavigatorState>();
  final _addKey = GlobalKey<AddTransactionScreenState>();
  final _tab = ValueNotifier<int>(0);
  final _openingProfile = SingleFlight();
  final _openingNotifications = SingleFlight();
  final _openingForm = SingleFlight();
  late final List<Widget> _screens;
  late Future<List<FinanceEntry>> _headerEntries;

  @override
  void initState() {
    super.initState();
    _finance = widget.financeRepository ?? AppServices.finance;
    _profile = ProfileController(
      widget.profileRepository ?? AppServices.profile,
    )..loadPhoto();
    _headerEntries = _loadHeaderEntries();
    // Testes com repositório simulado não agendam lembretes reais.
    _reminders =
        widget.reminderService ??
        (widget.financeRepository == null ? AppServices.reminders : null);
    final owner = widget.userId;
    if (_reminders != null && owner != null) {
      _synchronizer = ReminderSynchronizer(
        reminders: _reminders!,
        owner: owner,
        loadEntries: () =>
            _finance.transactions(DateTime.now().add(_remindersHorizon)),
      );
    }
    WidgetsBinding.instance.addObserver(this);
    financeRevision.addListener(_onFinanceChanged);
    ReminderPreferences.time.addListener(_syncReminders);
    _reminders?.openRequested.addListener(_notificationTapped);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncReminders();
      _notificationTapped();
    });
    _screens = [
      DashboardScreen(
        repository: _finance,
        reminders: _reminders,
        onNavigateToNotifications: _openNotifications,
      ),
      FinanceRegistrationScreen(
        onAddExpense: () => _add(),
        onAddIncome: () => _add(kind: TransactionKind.income),
        onImport: _openImport,
      ),
      TransactionsListScreen(repository: _finance),
      ProfileScreen(
        controller: _profile,
        onNavigateToNotifications: _openNotifications,
      ),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    financeRevision.removeListener(_onFinanceChanged);
    ReminderPreferences.time.removeListener(_syncReminders);
    _reminders?.openRequested.removeListener(_notificationTapped);
    _synchronizer?.dispose();
    _profile.dispose();
    _tab.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) notifyFinanceChanged();
  }

  Future<List<FinanceEntry>> _loadHeaderEntries() =>
      _finance.transactions(DateTime.now().add(_headerHorizon));

  void _onFinanceChanged() {
    if (!mounted) return;
    setState(() {
      _headerEntries = _loadHeaderEntries();
    });
    _syncReminders();
  }

  void _syncReminders() {
    if (mounted) _synchronizer?.run();
  }

  void _notificationTapped() {
    if (!mounted || _reminders?.openRequested.value != true) return;
    _reminders!.openRequested.value = false;
    _openNotifications();
  }

  Future<void> _openNotifications() => _openingNotifications.run(() async {
    if (!mounted) return;
    await _navigator.currentState?.push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          repository: _finance,
          reminders: _reminders,
          owner: widget.userId,
        ),
      ),
    );
  });

  Future<void> _openImport() async {
    await _navigator.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ImportScreen(
          finance: _finance,
          repository: widget.importRepository ?? AppServices.imports,
        ),
      ),
    );
  }

  Future<void> _openProfile() => _openingProfile.run(() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.78,
        child: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => ProfileScreen(
              controller: _profile,
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
  });

  Future<void> _add({TransactionKind kind = TransactionKind.expense}) =>
      _openingForm.run(() async {
        if (!mounted) return;
        await _navigator.currentState?.push(
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(
              key: _addKey,
              initialKind: kind,
              repository: _finance,
              onEnableReminders: _openNotifications,
            ),
          ),
        );
      });

  Future<void> _onTabTapped(int index) async {
    final form = _addKey.currentState;
    if (form != null && !await form.requestLeave()) return;
    if (!mounted) return;
    _navigator.currentState?.popUntil((route) => route.isFirst);
    _tab.value = index;
  }

  @override
  Widget build(BuildContext context) => NavigatorPopHandler(
    onPopWithResult: (result) => _navigator.currentState?.maybePop(result),
    child: Scaffold(
      body: Column(
        children: [
          MainHeader(
            profile: _profile,
            entries: _headerEntries,
            onOpenProfile: _openProfile,
            onOpenNotifications: _openNotifications,
          ),
          Expanded(
            child: Navigator(
              key: _navigator,
              onGenerateRoute: (settings) => MaterialPageRoute(
                settings: settings,
                builder: (_) => ValueListenableBuilder<int>(
                  valueListenable: _tab,
                  builder: (_, index, __) =>
                      IndexedStack(index: index, children: _screens),
                ),
              ),
            ),
          ),
        ],
      ),
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
              label: 'Início',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Finanças',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Extrato',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    ),
  );
}
