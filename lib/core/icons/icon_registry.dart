import 'package:flutter/material.dart';

/// Resolves Material icon names coming from the menu API.
abstract final class IconRegistry {
  static const IconData fallback = Icons.widgets_outlined;

  static const Map<String, IconData> _icons = {
    'shopping_cart': Icons.shopping_cart_outlined,
    'receipt_long': Icons.receipt_long_outlined,
    'people': Icons.people_outline,
    'warehouse': Icons.warehouse_outlined,
    'inventory_2': Icons.inventory_2_outlined,
    'local_shipping': Icons.local_shipping_outlined,
    'bar_chart': Icons.bar_chart_outlined,
    'assessment': Icons.assessment_outlined,
    'analytics': Icons.analytics_outlined,
    'folder': Icons.folder_outlined,
    'settings': Icons.settings_outlined,
    'manage_accounts': Icons.manage_accounts_outlined,
    'dashboard': Icons.dashboard_outlined,
  };

  static IconData resolve(String? name) => _icons[name] ?? fallback;
}
