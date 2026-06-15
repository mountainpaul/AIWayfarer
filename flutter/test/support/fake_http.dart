import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A Dio [HttpClientAdapter] that returns canned responses and records every
/// request — no network, no package dependency. Shared harness for ApiClient
/// (and anything else built on Dio) tests.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  /// Maps an outgoing request to a canned [ResponseBody].
  final ResponseBody Function(RequestOptions options) handler;

  /// Every request that passed through, in order — assert on these.
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Build a JSON [ResponseBody] (object or list) with the given status.
ResponseBody jsonResponse(Object? data, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// A Dio whose transport is a [FakeAdapter]. Returns both so tests can assert
/// on captured requests.
({Dio dio, FakeAdapter adapter}) fakeDio(
  ResponseBody Function(RequestOptions options) handler, {
  String baseUrl = 'http://test.local/api/v1',
}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  final adapter = FakeAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}
