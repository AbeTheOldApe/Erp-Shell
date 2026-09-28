import 'package:flutter/widgets.dart';

import '../module_def.dart';
import '../placeholder_module_page.dart';

/// Orders. Becomes the list → detail sample in phase 3.
class SiparisModule extends StatelessWidget {
  const SiparisModule(this.ctx, {super.key});

  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) => PlaceholderModulePage(ctx: ctx);
}
