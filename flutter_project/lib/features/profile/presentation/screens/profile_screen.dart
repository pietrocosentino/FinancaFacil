import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/app_services.dart';
import '../../../../core/services/reminder_preferences.dart';
import '../../../../core/utils/finance_updates.dart';
import '../../data/profile_photo_store.dart';
import '../../data/profile_repository.dart';
import 'personal_data_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen(
      {super.key,
      this.repository,
      this.onNavigateToNotifications,
      this.photoStore,
      this.imagePicker});
  final ProfileRepository? repository;
  final VoidCallback? onNavigateToNotifications;
  final ProfilePhotoStore? photoStore;
  final ImagePicker? imagePicker;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileRepository _repository;
  late final ProfilePhotoStore _photos;
  Uint8List? _photo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AppServices.profile;
    _photos = widget.photoStore ?? ProfilePhotoStore();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final account = _repository.currentProfile?.email;
    if (account == null) return;
    try {
      final photo = await _photos.load(account);
      if (mounted) setState(() => _photo = photo);
    } catch (_) {
      // A missing local avatar never blocks access to the account.
    }
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Escolher da galeria'),
                  onTap: () => Navigator.pop(context, 'select')),
              if (_photo != null)
                ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Remover foto'),
                    onTap: () => Navigator.pop(context, 'remove')),
              const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child:
                      Text('Sua foto fica salva nesta conta, neste aparelho.')),
            ])));
    if (action == null || !mounted) return;
    final account = _repository.currentProfile?.email;
    if (account == null) return;
    setState(() => _busy = true);
    try {
      if (action == 'remove') {
        await _photos.remove(account);
        if (mounted) setState(() => _photo = null);
        _message('Foto removida.');
      } else {
        final file = await (widget.imagePicker ?? ImagePicker()).pickImage(
            source: ImageSource.gallery,
            maxWidth: 512,
            maxHeight: 512,
            imageQuality: 70,
            requestFullMetadata: false);
        if (file == null) return;
        final bytes = await file.readAsBytes();
        if (bytes.length > ProfilePhotoStore.maxBytes) {
          _message('Escolha uma imagem menor, de até 200 KB após a redução.');
          return;
        }
        await _photos.save(account, bytes);
        if (mounted) setState(() => _photo = bytes);
        _message('Foto atualizada.');
      }
    } catch (_) {
      _message('Não foi possível atualizar a foto. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _personalData() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => PersonalDataScreen(repository: _repository)));
    if (mounted) setState(() {});
  }

  Future<void> _reminders() async {
    final time = await showTimePicker(
        context: context,
        initialTime: ReminderPreferences.time.value,
        helpText: 'Horário dos lembretes');
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                  padding: EdgeInsets.all(20), child: Text('Aparência')),
              for (final mode in ThemeMode.values)
                ListTile(
                    title: Text(_themeName(mode)),
                    trailing: mode == ReminderPreferences.themeMode.value
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(context, mode)),
            ])));
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
                    'Os lembretes deste aparelho serão interrompidos até você entrar novamente.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sair'))
                ]));
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
        Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(children: children)),
      ]));

  Widget _item(IconData icon, String title, VoidCallback onTap,
          {String? subtitle}) =>
      ListTile(
          enabled: !_busy,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap);

  @override
  Widget build(BuildContext context) {
    final data = _repository.currentProfile;
    if (data == null) {
      return const Scaffold(
          body: Center(child: Text('Sua sessão terminou. Entre novamente.')));
    }
    return Scaffold(
        appBar: AppBar(title: const Text('Meu perfil'), centerTitle: false),
        body: SafeArea(
            top: false,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const SizedBox(height: 12),
              Center(
                  child: Semantics(
                      label: 'Alterar foto de perfil',
                      button: true,
                      child: InkWell(
                          onTap: _busy ? null : _changePhoto,
                          customBorder: const CircleBorder(),
                          child: Stack(children: [
                            CircleAvatar(
                                radius: 44,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                child: _photo == null
                                    ? Text(data.initials,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium)
                                    : ClipOval(
                                        child: Image.memory(_photo!,
                                            width: 88,
                                            height: 88,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Text(data.initials)))),
                            Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    child: Icon(Icons.camera_alt_outlined,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary))),
                          ])))),
              const SizedBox(height: 16),
              Text(data.name.isEmpty ? 'Minha conta' : data.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text('Minha conta', textAlign: TextAlign.center),
              TextButton(
                  onPressed: _busy ? null : _changePhoto,
                  child: Text(_busy ? 'Aguarde...' : 'Alterar foto')),
              _section('Minha conta', [
                _item(Icons.person_outline, 'Dados pessoais', _personalData,
                    subtitle: 'Nome, e-mail e telefone'),
              ]),
              _section('Preferências', [
                ValueListenableBuilder<TimeOfDay>(
                    valueListenable: ReminderPreferences.time,
                    builder: (_, time, __) => _item(
                        Icons.schedule_outlined, 'Lembretes', _reminders,
                        subtitle:
                            'Todos os dias às ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} · enquanto houver pendências')),
                const Divider(height: 1, indent: 56),
                ValueListenableBuilder<ThemeMode>(
                    valueListenable: ReminderPreferences.themeMode,
                    builder: (_, mode, __) => _item(
                        Icons.palette_outlined, 'Aparência', _appearance,
                        subtitle: _themeName(mode))),
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
                                    'Cadastre suas contas e o dia de vencimento. Os lembretes começam três dias antes. Confirme o pagamento manualmente na lista de notificações. Para receber alertas, permita as notificações nas configurações do aparelho.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Entendi'))
                                ]))),
                if (widget.onNavigateToNotifications != null)
                  _item(Icons.notifications_outlined, 'Minhas notificações',
                      widget.onNavigateToNotifications!),
              ]),
              const SizedBox(height: 28),
              TextButton.icon(
                  onPressed: _busy ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair da conta')),
              const SizedBox(height: 12),
            ])));
  }
}
