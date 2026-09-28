import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/session_controller.dart';
import '../core/l10n/locale_controller.dart';
import '../core/network/api_exception.dart';
import '../core/theme/app_theme.dart';
import 'side_menu/menu_providers.dart';
import 'tabs/tabs_notifier.dart';

/// Blocking "sign in again" dialog. The shell and its tabs stay in place
/// behind it; after signing in as the same user everything continues where
/// it was.
class SessionExpiredDialog extends ConsumerStatefulWidget {
  const SessionExpiredDialog({super.key});

  @override
  ConsumerState<SessionExpiredDialog> createState() =>
      _SessionExpiredDialogState();
}

class _SessionExpiredDialogState extends ConsumerState<SessionExpiredDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final user = ref.read(sessionProvider).user;
    if (_busy || user == null) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(user.username, _password.text);
      if (ref.read(menuProvider).hasError) ref.invalidate(menuProvider);
      if (mounted) Navigator.of(context).pop();
      return;
    } on UnauthorizedException {
      _error = l10n.loginFailed;
    } catch (_) {
      _error = l10n.loginUnexpectedError;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _signOut() async {
    Navigator.of(context).pop();
    await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final theme = Theme.of(context);
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final dirtyTitles = ref.watch(
      tabsProvider.select(
        (s) => [
          for (final tab in s.tabs)
            if (tab.isDirty) tab.title,
        ].join(', '),
      ),
    );

    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.lock_clock_outlined),
        title: Text(l10n.sessionExpiredTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.sessionExpiredMessage),
                if (dirtyTitles.isNotEmpty) ...[
                  SizedBox(height: spacing.md),
                  Text(
                    l10n.sessionExpiredDirtyTabs(dirtyTitles),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                SizedBox(height: spacing.md),
                Text(
                  l10n.sessionExpiredUser(user?.displayName ?? ''),
                  style: theme.textTheme.labelLarge,
                ),
                SizedBox(height: spacing.sm),
                TextField(
                  controller: _password,
                  autofocus: true,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.loginPassword,
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _signIn(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _signOut,
            child: Text(l10n.logout),
          ),
          FilledButton(
            onPressed: _busy ? null : _signIn,
            child: Text(l10n.loginButton),
          ),
        ],
      ),
    );
  }
}
