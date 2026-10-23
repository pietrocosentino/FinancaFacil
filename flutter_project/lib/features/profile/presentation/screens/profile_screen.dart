import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/errors/app_log.dart';
import '../../../../core/services/device_preferences.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../data/profile_photo_source.dart';
import '../../data/profile_photo_store.dart';
import '../../data/profile_repository.dart';
import '../profile_controller.dart';
import '../profile_menu_item.dart';
import 'personal_data_screen.dart';

/// Menu do perfil. Recebe o [controller] compartilhado com o cabeçalho ou,
/// isoladamente, um [repository] para criar o próprio controlador.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.controller,
    this.repository,
    this.photoSource,
    this.extraItems = const [],
  }) : assert(controller != null || repository != null);
  final ProfileController? controller;
  final ProfileRepository? repository;
  final ProfilePhotoSource? photoSource;
  final List<ProfileMenuItem> extraItems;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller;
  late final ProfilePhotoSource _photos;
  bool _busy = false;

  ProfileRepository get _repository => _controller.repository;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ProfileController(widget.repository!);
    _photos = widget.photoSource ?? DeviceProfilePhotoSource();
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
        final Uint8List? bytes = action == 'files'
            ? await _photos.fromFiles()
            : await _photos.fromGallery();
        if (bytes == null) return;
        if (bytes.length > ProfilePhotoStore.maxBytes) {
          _message('Escolha uma imagem menor, de até 200 KB após a redução.');
          return;
        }
        await _controller.savePhoto(bytes);
        _message('Foto atualizada.');
      }
    } on FormatException catch (error) {
      _message(error.message);
    } catch (error, stack) {
      AppLog.error(error, stack, 'alterar foto');
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
      initialTime: DevicePreferences.time.value,
      helpText: 'Horário dos lembretes',
    );
    if (time == null || !mounted) return;
    setState(() => _busy = true);
    try {
      // O layout principal observa o horário e reagenda os lembretes.
      await DevicePreferences.setTime(time);
      _message('Horário dos lembretes atualizado.');
    } catch (error, stack) {
      AppLog.error(error, stack, 'horário dos lembretes');
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
                trailing: mode == DevicePreferences.themeMode.value
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
      await DevicePreferences.setTheme(mode);
    } catch (error, stack) {
      AppLog.error(error, stack, 'aparência');
      _message('Não foi possível salvar a aparência.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sair da conta?',
      message: 'Os lembretes deste aparelho serão interrompidos até você entrar novamente.',
      confirmLabel: 'Sair',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.signOut();
    } catch (error, stack) {
      AppLog.error(error, stack, 'sair');
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
      appBar: AppBar(title: const Text('Meu perfil'), centerTitle: false),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
                valueListenable: DevicePreferences.time,
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
                valueListenable: DevicePreferences.themeMode,
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
                    title: const Text('Como funciona'),
                    scrollable: true,
                    content: const Text(
                      'Toque em Adicionar para cadastrar uma conta, uma renda ou importar uma planilha.\n\n'
                      'Contas: os lembretes começam três dias antes do vencimento. Depois de pagar, confirme pelo sino ou no Extrato. O app não faz pagamentos.\n\n'
                      'Rendas mensais: entram no saldo automaticamente na data cadastrada. Se não recebeu, abra o lançamento no Extrato e escolha "Não recebi"; ele fica pendente até você confirmar.\n\n'
                      'Para receber alertas com o app fechado, permita as notificações nas configurações do aparelho.',
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
