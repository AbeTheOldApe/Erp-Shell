import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_models.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/session_controller.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';

/// Sign-in page. After signing in the router guard sends the user to
/// [from] (the page they originally asked for) or home.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({this.from, super.key});

  final String? from;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(_username.text, _password.text);
    } on UnauthorizedException {
      _error = l10n.loginFailed;
    } catch (_) {
      _error = l10n.loginUnexpectedError;
    }
    if (mounted) setState(() => _busy = false);
  }

  void _useDemo(DemoAccount account) {
    _username.text = account.username;
    _password.text = account.password;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final theme = Theme.of(context);
    final demoAccounts = ref.watch(authRepositoryProvider).demoAccounts;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(spacing.lg),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.loginTitle,
                            style: theme.textTheme.headlineSmall,
                          ),
                          SizedBox(height: spacing.xs),
                          Text(
                            l10n.loginSubtitle,
                            style: theme.textTheme.bodyMedium,
                          ),
                          SizedBox(height: spacing.lg),
                          TextFormField(
                            controller: _username,
                            autofocus: true,
                            enabled: !_busy,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: InputDecoration(
                              labelText: l10n.loginUsername,
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? l10n.loginUsernameRequired
                                : null,
                          ),
                          SizedBox(height: spacing.md),
                          TextFormField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: l10n.loginPassword,
                            ),
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          if (_error != null) ...[
                            SizedBox(height: spacing.md),
                            Text(
                              _error!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                          SizedBox(height: spacing.lg),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(l10n.loginButton),
                          ),
                          if (demoAccounts.isNotEmpty) ...[
                            SizedBox(height: spacing.lg),
                            Text(
                              l10n.loginDemoAccounts,
                              style: theme.textTheme.labelLarge,
                            ),
                            SizedBox(height: spacing.sm),
                            Wrap(
                              spacing: spacing.sm,
                              runSpacing: spacing.sm,
                              children: [
                                for (final account in demoAccounts)
                                  ActionChip(
                                    avatar: const Icon(Icons.person_outline),
                                    label: Text(account.username),
                                    tooltip: account.description,
                                    onPressed: _busy
                                        ? null
                                        : () => _useDemo(account),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
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
