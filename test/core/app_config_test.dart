import 'package:flutter_test/flutter_test.dart';

import 'package:erp_shell/core/config/app_config.dart';

void main() {
  // No --dart-define is passed in tests, so runtime values apply.
  test('uses defaults without config.json', () {
    final config = AppConfig.resolve();
    expect(config.useMock, isFalse);
    expect(config.apiBaseUrl, '/api/v1');
  });

  test('reads runtime config.json values', () {
    final config = AppConfig.resolve({'apiBaseUrl': '/x/v2', 'useMock': true});
    expect(config.useMock, isTrue);
    expect(config.apiBaseUrl, '/x/v2');
  });

  test('ignores invalid runtime values', () {
    final config = AppConfig.resolve({'apiBaseUrl': 5, 'useMock': 'yes'});
    expect(config.useMock, isFalse);
    expect(config.apiBaseUrl, '/api/v1');
  });
}
