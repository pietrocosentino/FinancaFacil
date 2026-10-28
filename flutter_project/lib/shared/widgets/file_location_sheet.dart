import 'package:flutter/material.dart';

import '../../core/files/cloud_files.dart';

/// Pergunta onde salvar um arquivo: no celular ou no Google Drive.
Future<FileLocation?> showSaveLocationSheet(
  BuildContext context, {
  required String title,
}) => showModalBottomSheet<FileLocation>(
  context: context,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ListTile(
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.phone_android),
          title: Text(FileLocation.device.saveLabel),
          subtitle: const Text('Salve em Downloads ou outra pasta'),
          onTap: () => Navigator.pop(context, FileLocation.device),
        ),
        ListTile(
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.add_to_drive_outlined),
          title: Text(FileLocation.drive.saveLabel),
          subtitle: const Text('Salve no Google Drive'),
          onTap: () => Navigator.pop(context, FileLocation.drive),
        ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);
