limport 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_log.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/services/device_biometrics.dart';
import '../../../../core/services/device_preferences.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../data/auth_gateway.dart';
import '../../data/auth_session_service.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.biometrics});
  final BiometricAuthenticator? biometrics;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  late final AuthSessionService _session;
  final AuthGateway _auth = AppServices.auth;
  StreamSubscription<SessionEvent>? _authSubscription;
  StreamSubscription<Uri>? _linkSubscription;
  String? _userId;
  bool _locked = false;
  bool _authenticating = false;
  String? _unlockError;
  bool _recovery = false;
  String? _error;

  BiometricAuthenticator get _biometrics =>
      widget.biometrics ?? AppServices.biometrics;

  @override
  void initState() {
    super.initState();
    _session = AppServices.session;
    _userId = _session.userId;
    _locked = _userId != null && DevicePreferences.biometricsEnabled.value;
    WidgetsBinding.instance.addObserver(this);
    DevicePreferences.biometricsEnabled.addListener(_biometricPreferenceChanged);
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticate();
      });
    }
    _authSubscription = _session.changes.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _error = null;
          final previousUserId = _userId;
          _userId = event == SessionEvent.signedOut ? null : _session.userId;
          if (event == SessionEvent.passwordRecovery) _recovery = true;
          if (event == SessionEvent.signedOut) {
            _recovery = false;
            _locked = false;
            _unlockError = null;
            unawaited(AppServices.reminders.clear().catchError((Object _) {}));
          } else if (_userId != null && _userId != previousUserId) {
            _locked = DevicePreferences.biometricsEnabled.value;
            _unlockError = null;
          }
        });
        if (_locked) _authenticate();
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _recovery = false;
            _error = 'Não foi possível validar o link. Solicite um novo e tente novamente.';
          });
        }
      },
    );
    final links = AppLinks();
    _linkSubscription = links.uriLinkStream.listen(
      _handleLink,
      onError: (Object error) {
        if (mounted) {
          setState(() => _error = 'Não foi possível abrir o link de acesso.');
        }
      },
    );
    _readInitialLink(links);
  }

  void _biometricPreferenceChanged() {
    if (!mounted) return;
    if (!DevicePreferences.biometricsEnabled.value) {
      setState(() {
        _locked = false;
        _unlockError = null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!DevicePreferences.biometricsEnabled.value || _userId == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_authenticating) {
        setState(() {
          _locked = true;
          _unlockError = null;
        });
      }
    } else if (state == AppLifecycleState.resumed && _locked) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (!_locked || _authenticating || _userId == null) return;
    setState(() {
      _authenticating = true;
      _unlockError = null;
    });
    try {
      final authenticated = await _biometrics.authenticate(
        'Desbloqueie o FinançaFácil para acessar sua conta.',
      );
      if (mounted) {
        setState(() {
          _locked = !authenticated;
          if (!authenticated) {
            _unlockError = 'Autenticação cancelada. Tente novamente.';
          }
        });
      }
    } catch (error, stack) {
      AppLog.error(error, stack, 'desbloquear com biometria');
      if (mounted) {
        setState(() {
          _locked = true;
          _unlockError =
              'Não foi possível autenticar. Tente novamente ou use o bloqueio do aparelho.';
        });
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _readInitialLink(AppLinks links) async {
    try {
      final uri = await links.getInitialLink();
      if (uri != null && mounted) _handleLink(uri);
    } catch (error, stack) {
      AppLog.error(error, stack, 'link de acesso');
      if (mounted) {
        setState(() => _error = 'Não foi possível abrir o link de acesso.');
      }
    }
  }

  void _handleLink(Uri uri) {
    if (!mounted || uri.scheme != 'com.pietro.financafacil') return;
    // Supabase processa o token; aqui apenas preservamos o modo de recuperação.
    if (uri.host == 'reset-password') setState(() => _recovery = true);
  }

  Future<void> _cancelRecovery() async {
    try {
      await _session.signOut();
      if (mounted) setState(() => _recovery = false);
    } catch (error, stack) {
      AppLog.error(error, stack, 'cancelar recuperação');
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível encerrar a recuperação. Tente novamente.',
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DevicePreferences.biometricsEnabled.removeListener(
      _biometricPreferenceChanged,
    );
    _authSubscription?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;
    final child = userId == null
        ? LoginScreen(key: const ValueKey('login'), gateway: _auth)
        : _recovery
        ? LoginScreen(
            key: const ValueKey('recovery'),
            gateway: _auth,
            recovery: true,
            onPasswordUpdated: () => setState(() => _recovery = false),
            onRecoveryCancelled: _cancelRecovery,
          )
        : _locked
        ? Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'FinançaFácil bloqueado',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use a biometria ou o PIN, padrão ou senha do aparelho para continuar.',
                        textAlign: TextAlign.center,
                      ),
                      if (_unlockError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _unlockError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _authenticating ? null : _authenticate,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(
                          _authenticating
                              ? 'Aguardando autenticação...'
                              : 'Desbloquear',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : MainLayout(key: ValueKey(userId), userId: userId);
    return Column(
      children: [
        if (_error != null)
          SafeArea(
            bottom: false,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar aviso',
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      onPressed: () => setState(() => _error = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
