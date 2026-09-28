import 'package:flutter/widgets.dart';

import '../module_def.dart';
import '../placeholder_module_page.dart';

/// User management.
class KullaniciModule extends StatelessWidget {
  const KullaniciModule(this.ctx, {super.key});

  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) => PlaceholderModulePage(ctx: ctx);
}
