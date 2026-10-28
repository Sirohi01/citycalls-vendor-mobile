import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// One recorded request made by the app.
class RecordedRequest {
  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Object? body;
  RecordedRequest(this.method, this.path, this.query, this.body);

  @override
  String toString() => '$method $path';
}

/// A canned server answer: status code + JSON body.
class FakeResponse {
  final int status;
  final Object? json;
  const FakeResponse(this.status, this.json);

  /// citycalls-api's success envelope (lib/apiResponse.ts sendSuccess).
  factory FakeResponse.ok(Object? data) =>
      FakeResponse(200, {'success': true, 'message': 'ok', 'data': data});

  /// citycalls-api's error envelope.
  factory FakeResponse.error(int status, String message) =>
      FakeResponse(status, {'success': false, 'message': message, 'errors': []});
}

typedef FakeHandler = FakeResponse? Function(RecordedRequest request);

/// Dio adapter that answers from [handler] instead of the network, standing
/// in for citycalls-api in tests. Unhandled requests get a 404; a handler
/// can throw to simulate the network being down.
class FakeBackend implements HttpClientAdapter {
  final FakeHandler handler;
  final List<RecordedRequest> requests = [];
  FakeBackend(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final request = RecordedRequest(
        options.method, options.path, options.queryParameters, options.data);
    requests.add(request);
    final response =
        handler(request) ?? FakeResponse.error(404, 'Not found in fake');
    return ResponseBody.fromString(
      jsonEncode(response.json),
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Thrown from a handler to simulate "no internet".
DioException offline(RecordedRequest r) => DioException(
      requestOptions: RequestOptions(path: r.path),
      type: DioExceptionType.connectionError,
      message: 'offline',
    );
