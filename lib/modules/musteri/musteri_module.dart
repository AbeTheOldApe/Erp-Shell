import 'package:flutter/widgets.dart';

import '../module_def.dart';
import '../placeholder_module_page.dart';

/// Customers.
class MusteriModule extends StatelessWidget {
  const MusteriModule(this.ctx, {super.key});

  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) => PlaceholderModulePage(ctx: ctx);
}
