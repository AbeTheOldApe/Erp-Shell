import '../../core/l10n/generated/app_localizations.dart';
import 'data/siparis_models.dart';

String durumLabel(AppLocalizations l10n, SiparisDurum durum) => switch (durum) {
  SiparisDurum.acik => l10n.durumAcik,
  SiparisDurum.onaylandi => l10n.durumOnaylandi,
  SiparisDurum.sevkEdildi => l10n.durumSevkEdildi,
  SiparisDurum.iptal => l10n.durumIptal,
};
