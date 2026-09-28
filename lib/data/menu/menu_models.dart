import 'package:flutter/foundation.dart';

import '../../core/auth/permissions.dart';

/// A node of the `/me/menu` tree. Leaves carry a [moduleKey] and
/// [permissions]; groups carry [children].
@immutable
class MenuNode {
  const MenuNode({
    required this.id,
    required this.title,
    this.icon,
    this.moduleKey,
    this.sortOrder = 0,
    this.badge,
    this.permissions,
    this.children = const [],
  });

  factory MenuNode.fromJson(Map<String, dynamic> json) => MenuNode(
    id: json['id'] as int,
    title: json['title'] as String,
    icon: json['icon'] as String?,
    moduleKey: json['moduleKey'] as String?,
    sortOrder: json['sortOrder'] as int? ?? 0,
    badge: json['badge']?.toString(),
    permissions: json['permissions'] == null
        ? null
        : ModulePermissions.fromJson(
            json['permissions'] as Map<String, dynamic>,
          ),
    children: [
      for (final child in json['children'] as List<dynamic>? ?? [])
        MenuNode.fromJson(child as Map<String, dynamic>),
    ],
  );

  final int id;
  final String title;
  final String? icon;
  final String? moduleKey;
  final int sortOrder;
  final String? badge;
  final ModulePermissions? permissions;
  final List<MenuNode> children;

  bool get isLeaf => moduleKey != null;

  MenuNode copyWith({List<MenuNode>? children}) => MenuNode(
    id: id,
    title: title,
    icon: icon,
    moduleKey: moduleKey,
    sortOrder: sortOrder,
    badge: badge,
    permissions: permissions,
    children: children ?? this.children,
  );
}

List<MenuNode> parseMenuResponse(Map<String, dynamic> json) => [
  for (final node in json['menu'] as List<dynamic>? ?? [])
    MenuNode.fromJson(node as Map<String, dynamic>),
];
