import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../shared/app_data_grid/app_data_grid.dart';
import '../../shared/filter_bar/filter_bar.dart';
import '../../shared/responsive_scaffold/responsive_scaffold.dart';
import '../module_def.dart';
import 'data/cari_models.dart';
import 'data/cari_repository.dart';

/// Cari list: search, role and "show inactive" filters, grid, "Yeni" (with
/// add permission). The API cannot sort, so no column is sortable.
class CariListPage extends ConsumerStatefulWidget {
  const CariListPage({
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
  ConsumerState<CariListPage> createState() => _CariListPageState();
}

class _CariListPageState extends ConsumerState<CariListPage> {
  List<GridFilter> _filters = const [];

  static String _roles(AppLocalizations l10n, CariOzet c) => [
    if (c.musteri) l10n.cariRoleMusteri,
    if (c.urunTedarikcisi) l10n.cariRoleUrunTedarikci,
    if (c.hizmetTedarikcisi) l10n.cariRoleHizmetTedarikci,
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ResponsiveScaffold(
      title: Text(
        widget.ctx.title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      actions: [
        if (widget.ctx.permissions.canAdd)
          PageAction(
            icon: Icons.add,
            label: l10n.actionNew,
            onPressed: widget.onNew,
            primary: true,
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterBar(
            debounce: const Duration(milliseconds: 300),
            fields: [
              TextFilterField(CariFilters.arama, l10n.cariSearch),
              BoolFilterField(CariFilters.musteri, l10n.cariRoleMusteri),
              BoolFilterField(
                CariFilters.urunTedarikcisi,
                l10n.cariRoleUrunTedarikci,
              ),
              BoolFilterField(
                CariFilters.hizmetTedarikcisi,
                l10n.cariRoleHizmetTedarikci,
              ),
              BoolFilterField(CariFilters.pasif, l10n.cariShowPassive),
            ],
            onChanged: (filters) => setState(() => _filters = filters),
          ),
          Expanded(
            child: AppDataGrid<CariOzet>(
              gridId: 'liste',
              moduleKey: widget.ctx.moduleKey,
              controller: widget.gridController,
              source: ref.watch(cariGridSourceProvider),
              filters: _filters,
              pageSize: 50,
              onOpen: (row) => widget.onOpen(row.id),
              columns: [
                AppGridColumn(
                  field: 'kod',
                  title: l10n.cariColKod,
                  value: (r) => r.kod,
                  width: 120,
                  sortable: false,
                ),
                AppGridColumn(
                  field: 'unvan',
                  title: l10n.cariColUnvan,
                  value: (r) => r.unvan,
                  width: 280,
                  sortable: false,
                  cardTitle: true,
                ),
                AppGridColumn(
                  field: 'kisaUnvan',
                  title: l10n.cariColKisaUnvan,
                  value: (r) => r.kisaUnvan,
                  width: 180,
                  sortable: false,
                  showInCard: false,
                ),
                AppGridColumn(
                  field: 'vergiTc',
                  title: l10n.cariColVergiTc,
                  value: (r) => r.vergiTc,
                  width: 170,
                  sortable: false,
                  showInCard: false,
                ),
                AppGridColumn(
                  field: 'telefon',
                  title: l10n.cariColTelefon,
                  value: (r) => r.telefon,
                  width: 150,
                  sortable: false,
                ),
                AppGridColumn(
                  field: 'ePosta',
                  title: l10n.cariColEposta,
                  value: (r) => r.ePosta,
                  width: 220,
                  sortable: false,
                  showInCard: false,
                ),
                AppGridColumn(
                  field: 'roller',
                  title: l10n.cariColRoller,
                  value: (r) => _roles(l10n, r),
                  width: 240,
                  sortable: false,
                  showInCard: false,
                ),
                AppGridColumn(
                  field: 'durum',
                  title: l10n.cariColDurum,
                  value: (r) =>
                      r.aktif ? l10n.cariStatusActive : l10n.cariStatusPassive,
                  width: 100,
                  sortable: false,
                  showInCard: false,
                ),
                AppGridColumn(
                  field: 'netsis',
                  title: l10n.cariColNetsis,
                  value: (r) => r.netsisBagli ? l10n.cariNetsisLinked : '',
                  width: 90,
                  sortable: false,
                  showInCard: false,
                  cell: (r) => r.netsisBagli
                      ? Builder(
                          builder: (context) => Tooltip(
                            message: l10n.cariNetsisLinked,
                            child: Icon(
                              Icons.link,
                              semanticLabel: l10n.cariNetsisLinked,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
