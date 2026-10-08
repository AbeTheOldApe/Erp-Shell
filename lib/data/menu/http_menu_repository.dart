import 'menu_models.dart';
import 'menu_repository.dart';

/// Menu for the real API. Until the client-side menu definition arrives
/// (`docs/api-contract.md` §5, phase 4.3) it is empty: the Cockpit is the
/// home tab and is not listed in the menu.
class HttpMenuRepository implements MenuRepository {
  const HttpMenuRepository();

  @override
  Future<List<MenuNode>> fetchMenu() async => const [];
}
