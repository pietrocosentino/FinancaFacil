import 'package:flutter/material.dart';

import '../../../../core/utils/auth_validators.dart';
import '../../../../core/utils/phone_formatter.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../data/profile_repository.dart';

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key, required this.repository, this.onSaved});
  final ProfileRepository repository;
  final VoidCallback? onSaved;
  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  bool _editing = false;
  String? _error;
  bool _allowExit = false;

  ProfileRepository get _repository => widget.repository;

  @override
  void initState() {
    super.initState();
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
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados do perfil atualizados.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível salvar. Verifique a conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool get _dirty {
    final data = _repository.currentProfile;
    return _editing &&
        (_name.text.trim() != (data?.name ?? '') ||
            phoneDigits(_phone.text) != phoneDigits(data?.phone ?? ''));
  }

  Future<void> _leave(bool didPop) async {
    if (didPop || _busy || !_dirty) return;
    final discard = await showConfirmDialog(
      context,
      title: 'Descartar alterações?',
      message: 'Seus dados ainda não foram salvos.',
      cancelLabel: 'Continuar editando',
      confirmLabel: 'Descartar',
    );
    if (!discard || !mounted) return;
    setState(() => _allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Widget _dataRow(String title, String value) => Card(
    child: ListTile(
      title: Text(title, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(
        value.isEmpty ? 'Não informado' : value,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final data = _repository.currentProfile;
    if (data == null) {
      return const Scaffold(
        body: Center(child: Text('Sua sessão terminou. Entre novamente.')),
      );
    }
    return PopScope(
      canPop: _allowExit || (!_busy && !_dirty),
      onPopInvokedWithResult: (didPop, result) => _leave(didPop),
      child: Scaffold(
        appBar: AppBar(title: const Text('Dados pessoais'), centerTitle: false),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_editing)
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        enabled: !_busy,
                        validator: validateName,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Nome'),
                      ),
                      const SizedBox(height: 12),
                      _dataRow('E-mail da conta', data.email),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        enabled: !_busy,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? null
                            : validatePhone(value),
                        inputFormatters: [PhoneInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Telefone com DDD',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_busy ? 'Salvando...' : 'Salvar dados'),
                      ),
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
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                )
              else ...[
                _dataRow('Nome', data.name),
                _dataRow('E-mail', data.email),
                _dataRow('Telefone', formatPhone(data.phone)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _loadFields();
                      _editing = true;
                      _error = null;
                    }),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text('Alterar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
