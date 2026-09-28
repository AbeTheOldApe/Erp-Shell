import 'package:flutter/widgets.dart';

import '../module_def.dart';
import '../placeholder_module_page.dart';

/// Stock status.
class StokModule extends StatelessWidget {
  const StokModule(this.ctx, {super.key});

  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) => PlaceholderModulePage(ctx: ctx);
}
