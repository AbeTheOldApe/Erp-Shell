import 'dart:convert';

import 'package:flutter/services.dart';

import '../mock/mock_backend.dart';
import 'menu_models.dart';
import 'menu_repository.dart';

/// Serves `/me/menu` from `assets/mock/menu_<username>.json`.
class MockMenuRepository implements MenuRepository {
  MockMenuRepository({
    required MockBackend backend,
    required AssetBundle bundle,
    required String? Function() accessToken,
  }) : _backend = backend,
       _bundle = bundle,
       _accessToken = accessToken;

  final MockBackend _backend;
  final AssetBundle _bundle;
  final String? Function() _accessToken;

  @override
  Future<List<MenuNode>> fetchMenu() async {
    await _backend.latency();
    final username = _backend.authenticate(_accessToken());
    final raw = await _bundle.loadString('assets/mock/menu_$username.json');
    return parseMenuResponse(jsonDecode(raw) as Map<String, dynamic>);
  }
}
