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
      return Semantics(
        button: onTap != null,
        label: 'Abrir menu do perfil',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: controller.photo == null
                      ? Text(data?.initials ?? '?')
                      : ClipOval(
                          child: Image.memory(
                            controller.photo!,
                            width: 40,
                            height: 40,
                            cacheWidth: 80,
                            cacheHeight: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Text(data?.initials ?? '?'),
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
                if (onTap != null) const Icon(Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
      );
    },
  );
}
