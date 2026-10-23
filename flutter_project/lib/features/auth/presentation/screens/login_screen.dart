import 'package:flutter/material.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/auth_validators.dart';
import '../../../../core/utils/phone_formatter.dart';
import '../../data/auth_gateway.dart';

enum AuthFormMode { login, register, forgotPassword, newPassword }

class LoginScreen extends StatefulWidget {
  final AuthGateway gateway;
  final bool recovery;
  final VoidCallback? onPasswordUpdated;
  final VoidCallback? onRecoveryCancelled;
  const LoginScreen({
    super.key,
    required this.gateway,
    this.recovery = false,
    this.onPasswordUpdated,
    this.onRecoveryCancelled,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late AuthFormMode _mode;
  bool _busy = false;
  bool _hidden = true;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mode = widget.recovery ? AuthFormMode.newPassword : AuthFormMode.login;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changeMode(AuthFormMode mode) {
    if (_busy) return;
    _form.currentState?.reset();
    setState(() {
      _mode = mode;
      _message = null;
      _error = null;
      _password.clear();
      _confirmation.clear();
    });
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    final mode = _mode;
    try {
      switch (mode) {
        case AuthFormMode.login:
          await widget.gateway.signIn(_email.text.trim(), _password.text);
          break;
        case AuthFormMode.register:
          final confirmationRequired = await widget.gateway.signUp(
            _name.text.trim(),
            _email.text.trim(),
            phoneDigits(_phone.text),
            _password.text,
          );
          if (!mounted) return;
          _changeModeAfterRequest(AuthFormMode.login);
          setState(
            () => _message = confirmationRequired
                ? 'Verifique seu e-mail para confirmar o cadastro. Depois, entre com sua senha.'
                : 'Cadastro concluído.',
          );
          break;
        case AuthFormMode.forgotPassword:
          await widget.gateway.requestPasswordReset(_email.text.trim());
          if (mounted) {
            setState(
              () => _message = 'Se houver uma conta para esse e-mail, você receberá um link para criar uma nova senha. Confira também o spam.',
            );
          }
          break;
        case AuthFormMode.newPassword:
          await widget.gateway.updatePassword(_password.text);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Senha atualizada com sucesso.')),
          );
          widget.onPasswordUpdated?.call();
          break;
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível conectar. Verifique a internet e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeModeAfterRequest(AuthFormMode mode) {
    _password.clear();
    _confirmation.clear();
    setState(() => _mode = mode);
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    bool password = false,
    Iterable<String>? autofillHints,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(label),
      controller: controller,
      enabled: !_busy,
      keyboardType: keyboard,
      inputFormatters: keyboard == TextInputType.phone
          ? [PhoneInputFormatter()]
          : null,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
      textCapitalization: TextCapitalization.none,
      obscureText: password && _hidden,
      autocorrect: !password,
      enableSuggestions: !password,
      autofillHints: autofillHints,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        helperText: keyboard == TextInputType.phone
            ? 'Opcional. Inclua o DDD.'
            : password &&
                  label != 'Confirmar senha' &&
                  _mode != AuthFormMode.login
            ? 'Use pelo menos 8 caracteres.'
            : null,
        suffixIcon: password
            ? IconButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _hidden = !_hidden),
                tooltip: _hidden ? 'Mostrar senha' : 'Ocultar senha',
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final register = _mode == AuthFormMode.register;
    final forgot = _mode == AuthFormMode.forgotPassword;
    final reset = _mode == AuthFormMode.newPassword;
    final title = register
        ? 'Criar conta'
        : forgot
        ? 'Recuperar senha'
        : reset
        ? 'Nova senha'
        : 'Entre na sua conta';
    final action = register
        ? 'Cadastrar'
        : forgot
        ? 'Enviar link de recuperação'
        : reset
        ? 'Salvar nova senha'
        : 'Entrar';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'FinançaFácil',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Lembretes para suas contas, antes do vencimento.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(title, textAlign: TextAlign.center),
                      const SizedBox(height: 28),
                      if (register)
                        _field(
                          'Nome',
                          _name,
                          validator: validateName,
                          autofillHints: const [AutofillHints.name],
                        ),
                      if (!reset)
                        _field(
                          'E-mail',
                          _email,
                          keyboard: TextInputType.emailAddress,
                          validator: validateEmail,
                          autofillHints: const [AutofillHints.email],
                        ),
                      if (register)
                        _field(
                          'Telefone com DDD',
                          _phone,
                          keyboard: TextInputType.phone,
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? null
                              : validatePhone(value),
                          autofillHints: const [AutofillHints.telephoneNumber],
                        ),
                      if (!forgot)
                        _field(
                          reset ? 'Nova senha' : 'Senha',
                          _password,
                          password: true,
                          validator: register || reset
                              ? validatePassword
                              : (value) => value == null || value.isEmpty
                                    ? 'Informe sua senha.'
                                    : null,
                          autofillHints: [
                            register || reset
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                        ),
                      if (register || reset)
                        _field(
                          'Confirmar senha',
                          _confirmation,
                          password: true,
                          validator: (value) =>
                              value != _password.text ||
                                  (value?.isEmpty ?? true)
                              ? 'As senhas precisam ser iguais.'
                              : null,
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: AppTheme.semanticColor(
                                context,
                                Colors.redAccent,
                              ),
                            ),
                          ),
                        ),
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color: AppTheme.semanticColor(
                                context,
                                AppTheme.mintNeon,
                              ),
                            ),
                          ),
                        ),
                      ElevatedButton(
                        onPressed: _busy ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(action),
                      ),
                      if (_mode == AuthFormMode.login) ...[
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _changeMode(AuthFormMode.forgotPassword),
                          child: const Text('Esqueci minha senha'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _changeMode(AuthFormMode.register),
                          child: const Text('Criar conta com e-mail'),
                        ),
                      ] else if (!reset)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _changeMode(AuthFormMode.login),
                          child: const Text('Voltar para o login'),
                        ),
                      if (reset)
                        TextButton(
                          onPressed: _busy ? null : widget.onRecoveryCancelled,
                          child: const Text('Cancelar recuperação'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
