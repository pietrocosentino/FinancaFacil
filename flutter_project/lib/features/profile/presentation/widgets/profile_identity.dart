import 'package:flutter/material.dart';

import '../profile_controller.dart';

class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity({super.key, required this.controller, this.onTap});
  final ProfileController controller;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (_, __) {
      final data = controller.profile;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Tooltip(
              message: 'Abrir perfil',
              child: Semantics(
                button: onTap != null,
                label: 'Abrir perfil',
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: controller.photo == null
                        ? Text(data?.initials ?? '?')
                        : ClipOval(
                            child: Image.memory(
                              controller.photo!,
                              width: 48,
                              height: 48,
                              cacheWidth: 96,
                              cacheHeight: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Text(data?.initials ?? '?'),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data?.name.isNotEmpty == true ? data!.name : 'Minha conta',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      );
    },
  );
}
