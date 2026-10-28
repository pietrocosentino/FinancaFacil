
import 'package:flutter/material.dart';

import '../../core/errors/app_log.dart';
import '../../core/files/cloud_files.dart';
import '../../core/services/app_services.dart';
import '../../core/services/device_preferences.dart';
import '../../core/utils/finance_updates.dart';
import '../../core/utils/single_flight.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/imports/data/import_file_gateway.dart';
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
import '../../features/transactions/presentation/screens/add_choice_sheet.dart';
import '../../features/transactions/presentation/screens/add_transaction_screen.dart';
import '../../features/transactions/presentation/screens/transactions_list_screen.dart';
import 'file_location_sheet.dart';
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
    this.importFiles,
    this.reminderService,
    this.userId,
  });
  final FinanceRepository? financeRepository;
  final ProfileRepository? profileRepository;
  final ImportRepository? importRepository;
  final ImportFileGateway? importFiles;
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

  /// Ao voltar ao app depois deste tempo (ou em outro dia), os dados são
  /// recarregados. Trocas rápidas de app não baixam o histórico de novo.
  static const _staleAfter = Duration(minutes: 1);

  static const _homeTab = 0;

  late final FinanceRepository _finance;
  late final ImportFileGateway _importFiles;
  late final ProfileController _profile;
  ReminderService? _reminders;
  ReminderSynchronizer? _synchronizer;
  final _navigator = GlobalKey<NavigatorState>();
  final _addKey = GlobalKey<AddTransactionScreenState>();
  final _tab = ValueNotifier<int>(_homeTab);
  final _choosing = SingleFlight();
  final _openingProfile = SingleFlight();
  final _openingNotifications = SingleFlight();
  final _openingForm = SingleFlight();
  final _downloadingTemplate = SingleFlight();
  late final List<Widget> _screens;
  late Future<List<FinanceEntry>> _headerEntries;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    _finance = widget.financeRepository ?? AppServices.finance;
    _importFiles = widget.importFiles ?? NativeImportFileGateway();
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
    DevicePreferences.time.addListener(_syncReminders);
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
        onAdd: _addEntry,
        onImportSpreadsheet: () => _addEntry(AddChoice.spreadsheet),
        onDownloadTemplate: _downloadTemplate,
      ),
      TransactionsListScreen(repository: _finance),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    financeRevision.removeListener(_onFinanceChanged);
    DevicePreferences.time.removeListener(_syncReminders);
    _reminders?.openRequested.removeListener(_notificationTapped);
    _synchronizer?.dispose();
    _profile.dispose();
    _tab.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = DateTime.now();
    switch (state) {
      case AppLifecycleState.resumed:
        final leftAt = _leftAt;
        _leftAt = null;
        if (leftAt == null ||
            now.difference(leftAt) >= _staleAfter ||
            now.day != leftAt.day) {
          notifyFinanceChanged();
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _leftAt ??= now;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
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

  Future<void> _downloadTemplate(BuildContext context) =>
      _downloadingTemplate.run(() async {
        final to = await showSaveLocationSheet(
          context,
          title: 'Onde salvar o modelo?',
        );
        if (to == null || !mounted) return;
        try {
          if (await _importFiles.saveTemplate(to) && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  to == FileLocation.drive
                      ? 'Confirme o envio no Google Drive. Depois, preencha a aba Lançamentos.'
                      : 'Modelo salvo. Preencha a aba Lançamentos.',
                ),
              ),
            );
          }
        } catch (error, stack) {
          AppLog.error(error, stack, 'salvar modelo');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Não foi possível salvar o modelo. Escolha uma pasta acessível no aparelho.',
                ),
              ),
            );
          }
        }
      });

  Future<void> _openProfile() => _openingProfile.run(() async {
    final form = _addKey.currentState;
    if (form != null && !await form.requestLeave()) return;
    if (!mounted) return;
    await _navigator.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(controller: _profile),
      ),
    );
  });

  void _addEntry(AddChoice choice) => _choosing.run(() async {
    if (!mounted) return;
    switch (choice) {
      case AddChoice.expense:
        await _add();
      case AddChoice.income:
        await _add(kind: TransactionKind.income);
      case AddChoice.spreadsheet:
        await _openImport();
    }
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
      // Cada tela interna já se ajusta ao teclado; ajustar aqui também
      // descontaria o espaço duas vezes e esconderia o formulário.
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // Com o teclado aberto o cabeçalho sai para o formulário ter espaço
          // em telas pequenas; fica só a área da barra de status.
          if (MediaQuery.viewInsetsOf(context).bottom > 0)
            BrandBar(
              child: SizedBox(
                height: MediaQuery.paddingOf(context).top,
                width: double.infinity,
              ),
            )
          else
            MainHeader(
              profile: _profile,
              entries: _headerEntries,
              onOpenProfile: _openProfile,
              onOpenNotifications: _openNotifications,
            ),
          // O cabeçalho já reserva a barra de status; sem isso cada tela
          // interna somaria o mesmo espaço de novo acima da própria AppBar.
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
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
          ),
        ],
      ),
      // Com o teclado aberto, o menu inferior sai de cena para o formulário
      // ocupar a tela até o teclado.
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : ValueListenableBuilder<int>(
              valueListenable: _tab,
              builder: (_, index, __) => NavigationBar(
                selectedIndex: index,
                onDestinationSelected: _onTabTapped,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    selectedIcon: Icon(Icons.account_balance_wallet),
                    label: 'Início',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: 'Extrato',
                  ),
                ],
              ),
            ),
    ),
  );
}
