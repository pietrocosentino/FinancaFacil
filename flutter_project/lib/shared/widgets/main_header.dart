import 'package:flutter/material.dart';

import '../../features/notifications/domain/reminder_plan.dart';
import '../../features/profile/presentation/profile_controller.dart';
import '../../features/profile/presentation/widgets/profile_identity.dart';
import '../../features/transactions/domain/finance_models.dart';

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
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                Text(
                  'FinançaFácil',
                  style: Theme.of(context).textTheme.labelMedium,
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
  );
}
