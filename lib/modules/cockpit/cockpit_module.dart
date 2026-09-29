import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../shared/states/empty_state.dart';
import '../module_def.dart';

/// Cockpit: the pinned home tab. Its content grows as business modules are
/// added; for now it is a placeholder.
class CockpitModule extends StatelessWidget {
  const CockpitModule(this.ctx, {super.key});

  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.dashboard_outlined,
    title: context.l10n.cockpitTitle,
    message: context.l10n.cockpitPlaceholder,
  );
}
