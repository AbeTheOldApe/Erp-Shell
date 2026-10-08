import 'package:flutter/foundation.dart';

/// Effective permissions of the user on a module.
@immutable
class ModulePermissions {
  const ModulePermissions({
    this.canView = false,
    this.canAdd = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  factory ModulePermissions.fromJson(Map<String, dynamic> json) =>
      ModulePermissions(
        canView: json['canView'] as bool? ?? false,
        canAdd: json['canAdd'] as bool? ?? false,
        canEdit: json['canEdit'] as bool? ?? false,
        canDelete: json['canDelete'] as bool? ?? false,
      );

  static const none = ModulePermissions();

  final bool canView;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;

  Map<String, dynamic> toJson() => {
    'canView': canView,
    'canAdd': canAdd,
    'canEdit': canEdit,
    'canDelete': canDelete,
  };

  @override
  bool operator ==(Object other) =>
      other is ModulePermissions &&
      other.canView == canView &&
      other.canAdd == canAdd &&
      other.canEdit == canEdit &&
      other.canDelete == canDelete;

  @override
  int get hashCode => Object.hash(canView, canAdd, canEdit, canDelete);
}

/// What `GET /me` returns under `Yetkiler` (`docs/api-contract.md` §4.2):
/// page codes and, per page, button codes.
@immutable
class ApiGrants {
  const ApiGrants({this.pages = const {}, this.buttons = const {}});

  factory ApiGrants.fromJson(Map<String, dynamic> json) {
    final buttons = json['Buttons'];
    return ApiGrants(
      pages: {
        for (final page in json['Pages'] as List<dynamic>? ?? []) '$page',
      },
      buttons: {
        if (buttons is Map)
          for (final entry in buttons.entries)
            '${entry.key}': {
              for (final code in entry.value as List<dynamic>? ?? []) '$code',
            },
      },
    );
  }

  static const none = ApiGrants();

  final Set<String> pages;
  final Map<String, Set<String>> buttons;

  bool hasPage(String pageCode) => pages.contains(pageCode);

  bool hasButton(String pageCode, String buttonCode) =>
      buttons[pageCode]?.contains(buttonCode) ?? false;
}
