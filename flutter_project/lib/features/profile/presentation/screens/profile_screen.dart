import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/files/selected_file_reader.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/services/reminder_preferences.dart';
import '../../../../core/utils/finance_updates.dart';
import '../../data/profile_image_decoder.dart';
import '../../data/profile_photo_store.dart';
import '../../data/profile_repository.dart';
import '../profile_controller.dart';
import '../profile_menu_item.dart';
import '../widgets/profile_identity.dart';
import 'personal_data_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.repository,
    this.onNavigateToNotifications,
    this.photoStore,
    this.imagePicker,
    this.controller,
    this.extraItems = const [],
    this.showIdentity = true,
    this.onClose,
  });
  final ProfileRepository? repository;
  final VoidCallback? onNavigateToNotifications;
  final ProfilePhotoStore? photoStore;
  final ImagePicker? imagePicker;
  final ProfileController? controller;
  final List<ProfileMenuItem> extraItems;
  final bool showIdentity;
  final VoidCallback? onClose;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileRepository _repository;
  late final ProfileController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.controller?.repository ??
        widget.repository ??
        AppServices.profile;
    _controller =
        widget.controller ??
        ProfileController(_repository, photos: widget.photoStore);
    _controller.loadPhoto();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _changePhoto() async {
    if (_busy) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, 'select'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Arquivos do aparelho ou nuvem'),
              subtitle: const Text('Google Drive e outros locais disponíveis'),
              onTap: () => Navigator.pop(context, 'files'),
            ),
            if (_controller.photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remover foto'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Text('Sua foto fica salva nesta conta, neste aparelho.'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final account = _repository.currentProfile?.email;
    if (account == null) return;
    setState(() => _busy = true);
    try {
      if (action == 'remove') {
        await _controller.removePhoto();
        _message('Foto removida.');
      } else {
        final Uint8List bytes;
        if (action == 'files') {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
            allowMultiple: false,
            withData: false,
            withReadStream: true,
          );
          if (result == null) return;
          final input = await readSelectedFile(
            result.files.single,
            5 * 1024 * 1024,
          );
          bytes = await prepareProfileImage(input);
        } else {
          final file = await (widget.imagePicker ?? ImagePicker()).pickImage(
            source: ImageSource.gallery,
            maxWidth: 512,
            maxHeight: 512,
            imageQuality: 70,
            requestFullMetadata: false,
          );
          if (file == null) return;
          bytes = await prepareProfileImage(await file.readAsBytes());
        }
        if (bytes.length > ProfilePhotoStore.maxBytes) {
          _message('Escolha uma imagem menor, de até 200 KB após a redução.');
          return;
        }
        await _controller.savePhoto(bytes);
        _message('Foto atualizada.');
      }
    } on FormatException catch (error) {
      _message(error.message);
    } catch (_) {
      _message(
        'Não foi possível atualizar a foto. Verifique a conexão e tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _personalData() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PersonalDataScreen(
          repository: _repository,
          onSaved: _controller.refresh,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _reminders() async {
    final time = await showTimePicker(
      context: context,
      initialTime: ReminderPreferences.time.value,
      helpText: 'Horário dos lembretes',
    );
    if (time == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ReminderPreferences.setTime(time);
      notifyFinanceChanged();
      _message('Horário dos lembretes atualizado.');
    } catch (_) {
      _message('Não foi possível salvar o horário. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _themeName(ThemeMode mode) => switch (mode) {
    ThemeMode.dark => 'Escuro',
    ThemeMode.light => 'Claro',
    ThemeMode.system => 'Sistema',
  };

  Future<void> _appearance() async {
    final mode = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aparência'),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(_themeName(mode)),
                trailing: mode == ReminderPreferences.themeMode.value
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, mode),
              ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ReminderPreferences.setTheme(mode);
    } catch (_) {
      _message('Não foi possível salvar a aparência.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Os lembretes deste aparelho serão interrompidos até você entrar novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.signOut();
    } catch (_) {
      _message('Não foi possível sair. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    ),
  );

  Widget _item(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? subtitle,
  }) => ListTile(
    enabled: !_busy,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final data = _repository.currentProfile;
    if (data == null) {
      return const Scaffold(
        body: Center(child: Text('Sua sessão terminou. Entre novamente.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
        centerTitle: false,
        automaticallyImplyLeading: widget.onClose == null,
        actions: [
          if (widget.onClose != null)
            IconButton(
              tooltip: 'Fechar menu',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.showIdentity) ProfileIdentity(controller: _controller),
            _section('Minha conta', [
              _item(Icons.photo_camera_outlined, 'Alterar foto', _changePhoto),
              for (final item in widget.extraItems)
                _item(
                  item.icon,
                  item.title,
                  item.onTap,
                  subtitle: item.subtitle,
                ),
              _item(
                Icons.person_outline,
                'Dados pessoais',
                _personalData,
                subtitle: 'Nome, e-mail e telefone',
              ),
            ]),
            _section('Preferências', [
              ValueListenableBuilder<TimeOfDay>(
                valueListenable: ReminderPreferences.time,
                builder: (_, time, __) => _item(
                  Icons.schedule_outlined,
                  'Lembretes',
                  _reminders,
                  subtitle:
                      'Todos os dias às ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} · enquanto houver pendências',
                ),
              ),
              const Divider(height: 1, indent: 56),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ReminderPreferences.themeMode,
                builder: (_, mode, __) => _item(
                  Icons.palette_outlined,
                  'Aparência',
                  _appearance,
                  subtitle: _themeName(mode),
                ),
              ),
            ]),
            _section('Ajuda', [
              _item(
                Icons.help_outline,
                'Como funciona',
                () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Seus lembretes'),
                    content: const Text(
                      'Cadastre suas contas e o dia de vencimento. Os lembretes começam três dias antes. Confirme o pagamento manualmente na lista de notificações. Para receber alertas, permita as notificações nas configurações do aparelho.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Entendi'),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.onNavigateToNotifications != null)
                _item(
                  Icons.notifications_outlined,
                  'Minhas notificações',
                  widget.onNavigateToNotifications!,
                ),
            ]),
            const SizedBox(height: 28),
            TextButton.icon(
              onPressed: _busy ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
