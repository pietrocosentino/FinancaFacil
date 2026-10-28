import 'package:flutter/material.dart';

import '../../core/files/cloud_files.dart';

/// Pergunta onde salvar um arquivo: no celular ou no Google Drive.
Future<FileLocation?> showSaveLocationSheet(
  BuildContext context, {
  required String title,
}) => showModalBottomSheet<FileLocation>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: Text(FileLocation.device.saveLabel),
              subtitle: const Text('Escolha a pasta, por exemplo Downloads'),
              onTap: () => Navigator.pop(context, FileLocation.device),
            ),
            ListTile(
              leading: const Icon(Icons.add_to_drive_outlined),
              title: Text(FileLocation.drive.saveLabel),
              subtitle: const Text(
                'Abre o "Salvar no Drive" do aplicativo Drive',
              ),
              onTap: () => Navigator.pop(context, FileLocation.drive),
            ),
          ],
        ),
      ),
    ),
  ),
);
