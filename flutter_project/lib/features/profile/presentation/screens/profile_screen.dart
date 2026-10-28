import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/errors/app_log.dart';
import '../../../../core/files/cloud_files.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/services/device_biometrics.dart';
import '../../../../core/services/device_preferences.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../data/profile_photo_source.dart';
import '../../data/profile_photo_store.dart';
import '../../data/profile_repository.dart';
import '../profile_controller.dart';
import '../profile_menu_item.dart';
import 'reminder_time_dialog.dart';
import 'personal_data_screen.dart';

/// Menu do perfil. Recebe o [controller] compartilhado com o cabeçalho ou,
/// isoladamente, um [repository] para criar o próprio controlador.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.controller,
    this.repository,
    this.biometrics,
    this.photoSource,
    this.extraItems = const [],
  }) : assert(controller != null || repository != null);
  final ProfileController? controller;
  final ProfileRepository? repository;
  final BiometricAuthenticator? biometrics;
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
  BiometricAuthenticator get _biometrics =>
      widget.biometrics ?? AppServices.biometrics;

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
      // Cinco opções não cabem na altura padrão em telas pequenas.
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeria do celular'),
                onTap: () => Navigator.pop(context, 'select'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Google Fotos'),
                onTap: () => Navigator.pop(context, 'photos'),
              ),
              ListTile(
                leading: const Icon(Icons.add_to_drive_outlined),
                title: const Text('Google Drive'),
                onTap: () => Navigator.pop(context, 'drive'),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('Arquivos do celular'),
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
        final Uint8List? bytes = switch (action) {
          'files' => await _photos.fromFiles(),
          'photos' => await _photos.fromGooglePhotos(),
          'drive' => await _photos.fromDrive(),
          _ => await _photos.fromGallery(),
        };
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
    } on CloudAppNotReady catch (error) {
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
    final time = await showDialog<TimeOfDay>(
      context: context,
      builder: (_) => ReminderTimeDialog(
        initialTime: DevicePreferences.time.value,
      ),
    );
    if (time == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await DevicePreferences.setTime(time);
      _message('Horário dos lembretes atualizado.');
    } catch (error, stack) {
      AppLog.error(error, stack, 'horário dos lembretes');
      _message('Não foi possível salvar o horário. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setBiometricsEnabled(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (enabled) {
        if (!await _biometrics.canAuthenticate) {
          _message(
            'Configure uma biometria no aparelho antes de ativar o bloqueio.',
          );
          return;
        }
        final authenticated = await _biometrics.authenticate(
          'Confirme sua identidade para ativar o bloqueio do FinançaFácil.',
        );
        if (!authenticated) {
          _message('Biometria não confirmada. O bloqueio não foi ativado.');
          return;
        }
      }
      await DevicePreferences.setBiometricsEnabled(enabled);
      _message(
        enabled
            ? 'Bloqueio biométrico ativado.'
            : 'Bloqueio biométrico desativado.',
      );
    } catch (error, stack) {
      AppLog.error(error, stack, 'configurar bloqueio biométrico');
      _message('Não foi possível configurar a biometria. Tente novamente.');
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
              ValueListenableBuilder<bool>(
                valueListenable: DevicePreferences.biometricsEnabled,
                builder: (_, enabled, __) => SwitchListTile(
                  secondary: Icon(
                    Icons.fingerprint,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Bloqueio biométrico'),
                  subtitle: const Text(
                    'Use digital ou rosto ao abrir o app ou voltar para ele. O PIN, padrão ou senha do aparelho também funciona.',
                  ),
                  value: enabled,
                  onChanged: _busy ? null : _setBiometricsEnabled,
                ),
              ),
              ValueListenableBuilder<TimeOfDay>(
                valueListenable: DevicePreferences.time,
                builder: (_, time, __) => _item(
                  Icons.schedule_outlined,
                  'Horário dos lembretes',
                  _reminders,
                  subtitle:
                      'Todos os dias às ${time.format(context)} · contas atrasadas ou vencendo em até 3 dias',
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
                      'Enquanto estiver pendente, o lançamento pode ser alterado ou excluído. Depois de confirmado, fica bloqueado: se confirmou por engano, use "Inativar" para tirá-lo dos totais. Em contas mensais, você também pode encerrar os próximos meses.\n\n'
                      'Rendas mensais: entram no saldo automaticamente na data cadastrada e podem ser alteradas a qualquer momento (valor, nome, dia e categoria). Se não recebeu, abra o lançamento no Extrato e escolha "Não recebi"; ele fica pendente até você confirmar.\n\n'
                      'Planilhas: em Adicionar → Importar planilha, envie o Excel do celular ou do Google Drive. Para baixar seus lançamentos, use o ícone de download no Extrato.\n\n'
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
