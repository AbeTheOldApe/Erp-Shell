import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// A canned API answer in the real API's envelope.
class FakeReply {
  const FakeReply(this.status, this.body);

  factory FakeReply.ok(Object? data) => FakeReply(200, {
    'IsSuccessful': true,
    'Message': 'Islem basarili.',
    'MessageCode': 200,
    'Data': data,
  });

  factory FakeReply.fail(int status, int code, String message) =>
      FakeReply(status, {
        'IsSuccessful': false,
        'Message': message,
        'MessageCode': code,
        'Data': null,
      });

  final int status;
  final Object? body;
}

class RecordedRequest {
  RecordedRequest(RequestOptions options)
    : method = options.method,
      path = options.path,
      headers = Map.of(options.headers),
      query = Map.of(options.queryParameters),
      body = options.data;

  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> query;
  final Object? body;
}

/// HTTP adapter that answers from [handler] and records the requests.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FutureOr<FakeReply> Function(RequestOptions options) handler;
  final requests = <RecordedRequest>[];

  int count(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(RecordedRequest(options));
    final reply = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

FakeReply tokenReply(String token) => FakeReply.ok({
  'AccessToken': token,
  'ExpiresIn': 900,
  'TokenType': 'Bearer',
});

/// `/me` data for a user with [pages] and [buttons] grants.
Map<String, Object?> meData({
  List<String> pages = const [],
  Map<String, List<String>> buttons = const {},
}) => {
  'Kullanici': {
    'AppUserId': 13,
    'TenantId': 2,
    'UserName': 'esin',
    'FullName': '',
    'Email': 'e@x.com',
  },
  'Ortam': 'Test',
  'Menu': [],
  'Yetkiler': {'Pages': pages, 'Buttons': buttons},
};
