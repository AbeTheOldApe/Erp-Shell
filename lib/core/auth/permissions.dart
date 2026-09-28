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
