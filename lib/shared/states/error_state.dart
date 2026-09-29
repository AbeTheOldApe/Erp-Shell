import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import 'empty_state.dart';

/// Error screen with an optional "Tekrar dene" button.
class ErrorState extends StatelessWidget {
  const ErrorState({this.message, this.onRetry, super.key});

  /// Defaults to a generic "could not load" text.
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      icon: Icons.error_outline,
      title: l10n.errorTitle,
      message: message ?? l10n.errorLoadFailed,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
    );
  }
}
