import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/app_log.dart';
import '../../../../core/services/app_services.dart';
import '../../../../shared/widgets/main_layout.dart';
import '../../data/auth_gateway.dart';
import '../../data/auth_session_service.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthSessionService _session;
  final AuthGateway _auth = AppServices.auth;
  StreamSubscription<SessionEvent>? _authSubscription;
  StreamSubscription<Uri>? _linkSubscription;
  String? _userId;
  bool _recovery = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _session = AppServices.session;
    _userId = _session.userId;
    _authSubscription = _session.changes.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _error = null;
          _userId = event == SessionEvent.signedOut ? null : _session.userId;
          if (event == SessionEvent.passwordRecovery) _recovery = true;
          if (event == SessionEvent.signedOut) {
            _recovery = false;
            unawaited(AppServices.reminders.clear().catchError((Object _) {}));
          }
        });
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
