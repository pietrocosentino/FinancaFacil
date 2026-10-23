import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../features/notifications/domain/reminder_plan.dart';
import '../../features/profile/presentation/profile_controller.dart';
import '../../features/profile/presentation/widgets/profile_identity.dart';
import '../../features/transactions/domain/finance_models.dart';

/// Faixa com a cor da marca no topo; também ocupa a área da barra de status,
/// que passa a usar ícones claros.
class BrandBar extends StatelessWidget {
  const BrandBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.brandDeep, colors.brand],
          ),
        ),
        child: Theme(
          data: theme.copyWith(
            textTheme: theme.textTheme.apply(
              bodyColor: colors.onBrand,
              displayColor: colors.onBrand,
            ),
            iconTheme: IconThemeData(color: colors.onBrand),
            colorScheme: theme.colorScheme.copyWith(
              primaryContainer: colors.onBrand,
              onPrimaryContainer: colors.brandDeep,
            ),
          ),
          child: IconTheme(
            data: IconThemeData(color: colors.onBrand),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho fixo: identidade do usuário, marca e sino com as pendências.
class MainHeader extends StatelessWidget {
  const MainHeader({
    super.key,
    required this.profile,
    required this.entries,
    required this.onOpenProfile,
    required this.onOpenNotifications,
  });

  final ProfileController profile;
  final Future<List<FinanceEntry>> entries;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) => BrandBar(
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: ProfileIdentity(controller: profile, onTap: onOpenProfile),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'FinançaFácil',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icon/icon.png',
                    width: 24,
                    height: 24,
                    cacheWidth: 48,
                  ),
                  const SizedBox(height: 2),
                  Builder(
                    builder: (context) => Text(
                      'FinançaFácil',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FutureBuilder<List<FinanceEntry>>(
              future: entries,
              builder: (_, snapshot) {
                final count = pendingBills(
                  snapshot.data ?? const [],
                  DateTime.now(),
                ).length;
                return IconButton(
                  tooltip: 'Notificações',
                  onPressed: onOpenNotifications,
                  color: AppColors.of(context).onBrand,
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
