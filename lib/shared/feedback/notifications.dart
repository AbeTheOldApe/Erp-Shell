import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';

/// Notification standards:
/// - success: short snackbar ([showSuccess]),
/// - error: banner that stays until dismissed ([showErrorBanner]),
/// - critical confirmation: dialog (`showConfirmDialog`).
void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
}

void showErrorBanner(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentMaterialBanner()
    ..showMaterialBanner(
      MaterialBanner(
        backgroundColor: scheme.errorContainer,
        leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
        content: Text(
          message,
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
}
