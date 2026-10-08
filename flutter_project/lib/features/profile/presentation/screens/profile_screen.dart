import 'package:flutter/material.dart';

import '../../../../core/services/app_services.dart';
import '../../../../core/services/reminder_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/auth_validators.dart';
import '../../../../core/utils/finance_updates.dart';
import '../../../../core/utils/phone_formatter.dart';
import '../../data/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen(
      {super.key, this.repository, this.onNavigateToNotifications});
  final ProfileRepository? repository;
  final VoidCallback? onNavigateToNotifications;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileRepository _repository;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  bool _editing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AppServices.profile;
    _loadFields();
  }

  void _loadFields() {
    final profile = _repository.currentProfile;
    _name.text = profile?.name ?? '';
    _phone.text = formatPhone(profile?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_repository.currentProfile == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.update(_name.text, phoneDigits(_phone.text));
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dados do perfil atualizados.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível salvar. Verifique a conexão e tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Encerrar sessão?'),
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.signOut();
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Não foi possível encerrar a sessão. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _repository.currentProfile;
    if (data == null) {
      return const Scaffold(
          body: Center(child: Text('Sua sessão terminou. Entre novamente.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil'), centerTitle: false),
      body: SafeArea(
          top: false,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(children: [
                      CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.mintNeon,
                          child: Text(data.initials,
                              style: const TextStyle(
                                  color: AppTheme.scaffoldBackground))),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                data.name.isEmpty
                                    ? 'Complete seu nome'
                                    : data.name,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(data.email),
                            const SizedBox(height: 6),
                            Text(data.phone.isEmpty
                                ? 'Telefone não informado'
                                : formatPhone(data.phone)),
                          ])),
                    ]))),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_error!,
                      style: TextStyle(
                          color: AppTheme.semanticColor(
                              context, Colors.redAccent)))),
            if (_editing)
              Form(
                  key: _form,
                  child: Column(children: [
                    TextFormField(
                        controller: _name,
                        enabled: !_busy,
                        validator: validateName,
                        decoration: const InputDecoration(labelText: 'Nome')),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _phone,
                        enabled: !_busy,
                        keyboardType: TextInputType.phone,
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? null
                            : validatePhone(value),
                        inputFormatters: [PhoneInputFormatter()],
                        decoration: const InputDecoration(
                            labelText: 'Telefone com DDD')),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_busy ? 'Salvando...' : 'Salvar dados')),
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                _loadFields();
                                setState(() {
                                  _editing = false;
                                  _error = null;
                                });
                              },
                        child: const Text('Cancelar')),
                  ]))
            else
              OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          _loadFields();
                          setState(() {
                            _editing = true;
                            _error = null;
                          });
                        },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar nome e telefone')),
            const SizedBox(height: 20),
            if (widget.onNavigateToNotifications != null)
              ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Consultar notificações'),
                  onTap: _busy ? null : widget.onNavigateToNotifications),
            ValueListenableBuilder<TimeOfDay>(
                valueListenable: ReminderPreferences.time,
                builder: (_, reminderTime, __) => ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Horário dos lembretes'),
                    subtitle: Text(
                        'Por volta das ${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}, diariamente enquanto houver pendências.'),
                    onTap: _busy
                        ? null
                        : () async {
                            final time = await showTimePicker(
                                context: context, initialTime: reminderTime);
                            if (time == null || !mounted) return;
                            try {
                              await ReminderPreferences.setTime(time);
                              if (mounted) setState(() {});
                              notifyFinanceChanged();
                            } catch (_) {
                              if (mounted) {
                                setState(() => _error =
                                    'Não foi possível salvar o horário. Tente novamente.');
                              }
                            }
                          })),
            ValueListenableBuilder<ThemeMode>(
                valueListenable: ReminderPreferences.themeMode,
                builder: (_, mode, __) => DropdownButtonFormField<ThemeMode>(
                    initialValue: mode,
                    decoration: const InputDecoration(labelText: 'Aparência'),
                    items: const [
                      DropdownMenuItem(
                          value: ThemeMode.dark, child: Text('Escuro')),
                      DropdownMenuItem(
                          value: ThemeMode.light, child: Text('Claro')),
                      DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('Usar tema do aparelho'))
                    ],
                    onChanged: _busy
                        ? null
                        : (value) async {
                            if (value == null) return;
                            try {
                              await ReminderPreferences.setTheme(value);
                            } catch (_) {
                              if (mounted) {
                                setState(() => _error =
                                    'Não foi possível salvar a aparência.');
                              }
                            }
                          })),
            const Divider(),
            ListTile(
                enabled: !_busy,
                leading: Icon(Icons.logout,
                    color: AppTheme.semanticColor(context, Colors.redAccent)),
                title: Text('Encerrar sessão',
                    style: TextStyle(
                        color:
                            AppTheme.semanticColor(context, Colors.redAccent))),
                onTap: _signOut),
          ])),
    );
  }
}
