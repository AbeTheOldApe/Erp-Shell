import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../shared/app_data_grid/app_data_grid.dart';
import '../../shared/feedback/notifications.dart';
import '../../shared/filter_bar/filter_bar.dart';
import '../../shared/responsive_scaffold/responsive_scaffold.dart';
import '../module_def.dart';
import 'data/siparis_models.dart';
import 'data/siparis_repository.dart';
import 'siparis_labels.dart';

/// Order list: filters, grid, "Yeni" (with add permission) and CSV export.
class SiparisListPage extends ConsumerStatefulWidget {
  const SiparisListPage({
    required this.ctx,
    required this.gridController,
    required this.onOpen,
    required this.onNew,
    super.key,
  });

  final ModuleContext ctx;
  final AppDataGridController gridController;
  final ValueChanged<int> onOpen;
  final VoidCallback onNew;

  @override
  ConsumerState<SiparisListPage> createState() => _SiparisListPageState();
}

class _SiparisListPageState extends ConsumerState<SiparisListPage> {
  List<GridFilter> _filters = const [];

  Future<void> _export() async {
    final l10n = context.l10n;
    final ok = await widget.gridController.exportCsv('siparisler.csv');
    if (!ok && mounted) showErrorBanner(context, l10n.exportFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final permissions = widget.ctx.permissions;

    return ResponsiveScaffold(
      title: Text(
        widget.ctx.title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      actions: [
        if (permissions.canAdd)
          PageAction(
            icon: Icons.add,
            label: l10n.actionNew,
            onPressed: widget.onNew,
            primary: true,
          ),
        PageAction(
          icon: Icons.download_outlined,
          label: l10n.actionExport,
          onPressed: _export,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterBar(
            fields: [
              TextFilterField('no', l10n.siparisNo),
              TextFilterField('musteri', l10n.siparisMusteri),
              SelectFilterField(
                'durum',
                l10n.siparisDurum,
                options: {
                  for (final d in SiparisDurum.values)
                    d.apiValue: durumLabel(l10n, d),
                },
              ),
              DateRangeFilterField('tarih', l10n.siparisTarih),
            ],
            onChanged: (filters) => setState(() => _filters = filters),
          ),
          Expanded(
            child: AppDataGrid<SiparisOzet>(
              gridId: 'liste',
              moduleKey: widget.ctx.moduleKey,
              controller: widget.gridController,
              source: ref.watch(siparisGridSourceProvider),
              filters: _filters,
              initialSort: const [GridSort('tarih', descending: true)],
              onOpen: (row) => widget.onOpen(row.id),
              columns: [
                AppGridColumn(
                  field: 'no',
                  title: l10n.siparisNo,
                  value: (r) => r.no,
                  width: 120,
                  cardTitle: true,
                ),
                AppGridColumn(
                  field: 'musteri',
                  title: l10n.siparisMusteri,
                  value: (r) => r.musteri,
                  width: 240,
                ),
                AppGridColumn(
                  field: 'tarih',
                  title: l10n.siparisTarih,
                  value: (r) => r.tarih,
                  kind: GridColumnKind.date,
                  width: 130,
                ),
                AppGridColumn(
                  field: 'durum',
                  title: l10n.siparisDurum,
                  value: (r) => durumLabel(l10n, r.durum),
                  width: 140,
                ),
                AppGridColumn(
                  field: 'tutar',
                  title: l10n.siparisTutar,
                  value: (r) => r.tutar,
                  kind: GridColumnKind.money,
                  width: 150,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
