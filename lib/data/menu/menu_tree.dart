import '../../core/utils/turkish_fold.dart';
import 'menu_models.dart';

/// Pure helpers for the menu tree. Kept free of Flutter so they are easy to
/// unit test.
abstract final class MenuTree {
  /// Maximum supported depth.
  static const maxDepth = 3;

  /// Sorts siblings by `sortOrder`, drops leaves the user cannot view,
  /// drops nodes deeper than [maxDepth] and hides groups without any
  /// visible leaf.
  static List<MenuNode> normalize(List<MenuNode> nodes) => _normalize(nodes, 1);

  static List<MenuNode> _normalize(List<MenuNode> nodes, int depth) {
    if (depth > maxDepth) return const [];
    final result = <MenuNode>[];
    for (final node in nodes) {
      if (node.isLeaf) {
        if (node.permissions?.canView ?? false) {
          result.add(node.copyWith(children: const []));
        }
        continue;
      }
      final children = _normalize(node.children, depth + 1);
      if (children.isNotEmpty) result.add(node.copyWith(children: children));
    }
    result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return result;
  }

  /// Filters the tree by [query] using [turkishFold]. A matching group keeps
  /// all of its children; otherwise only matching descendants are kept.
  static List<MenuNode> filter(List<MenuNode> nodes, String query) {
    final folded = turkishFold(query.trim());
    if (folded.isEmpty) return nodes;
    return _filter(nodes, folded);
  }

  static List<MenuNode> _filter(List<MenuNode> nodes, String folded) {
    final result = <MenuNode>[];
    for (final node in nodes) {
      if (turkishFold(node.title).contains(folded)) {
        result.add(node);
      } else if (!node.isLeaf) {
        final children = _filter(node.children, folded);
        if (children.isNotEmpty) result.add(node.copyWith(children: children));
      }
    }
    return result;
  }

  /// All leaves in display order.
  static List<MenuNode> leaves(List<MenuNode> nodes) => [
    for (final node in nodes)
      if (node.isLeaf) node else ...leaves(node.children),
  ];

  /// The leaf bound to [moduleKey], if the user can see it.
  static MenuNode? findLeaf(List<MenuNode> nodes, String moduleKey) {
    for (final node in nodes) {
      if (node.moduleKey == moduleKey) return node;
      final found = findLeaf(node.children, moduleKey);
      if (found != null) return found;
    }
    return null;
  }

  /// Ids of the groups above the leaf bound to [moduleKey], outermost first.
  /// Empty when the leaf is at the top level or not found.
  static List<int> ancestorIds(List<MenuNode> nodes, String moduleKey) {
    for (final node in nodes) {
      if (node.moduleKey == moduleKey) return const [];
      if (node.isLeaf) continue;
      if (findLeaf(node.children, moduleKey) != null) {
        return [node.id, ...ancestorIds(node.children, moduleKey)];
      }
    }
    return const [];
  }

  /// Ids of every group in the tree.
  static Set<int> groupIds(List<MenuNode> nodes) => {
    for (final node in nodes)
      if (!node.isLeaf) ...{node.id, ...groupIds(node.children)},
  };
}
