import 'package:flutter/material.dart';

import '../core/l10n/locale_controller.dart';
import '../core/theme/app_theme.dart';

/// Shown while the silent refresh at startup is running.
class StartupPage extends StatelessWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: context.spacing.md),
            Text(context.l10n.startupLoading),
          ],
        ),
      ),
    );
  }
}
