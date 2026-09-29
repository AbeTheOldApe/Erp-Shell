import 'package:flutter/material.dart';

import '../core/l10n/locale_controller.dart';
import '../shared/states/empty_state.dart';

class EmptyContentView extends StatelessWidget {
  const EmptyContentView({super.key});

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.touch_app_outlined,
    title: context.l10n.emptyStateSelectModule,
  );
}

class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key});

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.lock_outline,
    title: context.l10n.noAccessTitle,
    message: context.l10n.noAccessMessage,
  );
}

class ModuleNotFoundView extends StatelessWidget {
  const ModuleNotFoundView({required this.moduleKey, super.key});

  final String moduleKey;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.search_off,
    title: context.l10n.moduleNotFoundTitle,
    message: context.l10n.moduleNotFoundMessage(moduleKey),
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: context.l10n.loading,
      child: const CircularProgressIndicator(),
    ),
  );
}
