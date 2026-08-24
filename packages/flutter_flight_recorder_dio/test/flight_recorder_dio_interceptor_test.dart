import 'package:dio/dio.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';
import 'package:flutter_flight_recorder_dio/flutter_flight_recorder_dio.dart';
import 'package:flutter_test/flutter_test.dart';

RequestOptions _options({
  String method = 'GET',
  String url = 'https://api.example.com/profile',
  Object? data,
}) {
  return RequestOptions(path: url, method: method, data: data);
}

/// [ErrorInterceptorHandler.next] completes its internal future with the
/// error, which flutter_test treats as an unhandled async error and fails
/// the test unless something awaits and consumes it. This does that, so
/// tests can drive [FlightRecorderDioInterceptor.onError] directly
/// without dio actually propagating the error anywhere.
Future<void> _fireError(
  FlightRecorderDioInterceptor interceptor,
  DioException error,
) async {
  final handler = ErrorInterceptorHandler();
  interceptor.onError(error, handler);
  try {
    // ignore: invalid_use_of_protected_member
    await handler.future;
  } catch (_) {
    // Expected — onError always completes the handler with the error.
  }
}

void main() {
  setUp(FlightRecorder.init);
  tearDown(FlightRecorder.resetForTest);

  group('success', () {
    test('records method, url, status code and duration', () async {
      final interceptor = FlightRecorderDioInterceptor();
      final options = _options(method: 'GET');
      interceptor.onRequest(options, RequestInterceptorHandler());

      await Future<void>.delayed(const Duration(milliseconds: 5));
      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {'ok': true},
      );
      interceptor.onResponse(response, ResponseInterceptorHandler());

      final event = FlightRecorder.debugEvents.single;
      expect(event.category, EventCategory.network);
      expect(event.name, 'GET /profile');
      expect(event.metadata['method'], 'GET');
      expect(event.metadata['url'], 'https://api.example.com/profile');
      expect(event.metadata['statusCode'], 200);
      expect(event.metadata['durationMs'], isA<int>());
      expect(event.metadata['durationMs'], greaterThanOrEqualTo(0));
    });
  });

  group('HTTP failure', () {
    test('records the status code from a bad-response error', () async {
      final interceptor = FlightRecorderDioInterceptor();
      final options = _options(method: 'PATCH');
      interceptor.onRequest(options, RequestInterceptorHandler());

      final response =
          Response<dynamic>(requestOptions: options, statusCode: 422);
      final error = DioException(
        requestOptions: options,
        response: response,
        type: DioExceptionType.badResponse,
      );
      await _fireError(interceptor, error);

      final event = FlightRecorder.debugEvents.single;
      expect(event.name, 'PATCH /profile');
      expect(event.metadata['statusCode'], 422);
      expect(event.metadata['errorType'], 'badResponse');
    });
  });

  group('network failure', () {
    test('records errorType with no status code when there is no response',
        () async {
      final interceptor = FlightRecorderDioInterceptor();
      final options = _options();
      interceptor.onRequest(options, RequestInterceptorHandler());

      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
      await _fireError(interceptor, error);

      final event = FlightRecorder.debugEvents.single;
      expect(event.metadata['errorType'], 'connectionError');
      expect(event.metadata.containsKey('statusCode'), isFalse);
    });
  });

  group('timeout', () {
    test('records a connectionTimeout error type', () async {
      final interceptor = FlightRecorderDioInterceptor();
      final options = _options();
      interceptor.onRequest(options, RequestInterceptorHandler());

      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );
      await _fireError(interceptor, error);

      expect(
        FlightRecorder.debugEvents.single.metadata['errorType'],
        'connectionTimeout',
      );
    });
  });

  group('cancellation', () {
    test('records a cancel error type', () async {
      final interceptor = FlightRecorderDioInterceptor();
      final options = _options();
      interceptor.onRequest(options, RequestInterceptorHandler());

      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
      await _fireError(interceptor, error);

      expect(FlightRecorder.debugEvents.single.metadata['errorType'], 'cancel');
    });
  });

  group('duration', () {
    test(
        'is null-free (present) even when onRequest never ran for this options',
        () {
      final interceptor = FlightRecorderDioInterceptor();
      // No onRequest call — simulates a response object built without
      // going through this interceptor's onRequest first.
      final options = _options();
      final response =
          Response<dynamic>(requestOptions: options, statusCode: 200);
      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(
        FlightRecorder.debugEvents.single.metadata.containsKey('durationMs'),
        isFalse,
      );
    });
  });

  group('request/response body capture', () {
    test('is disabled by default — bodies are absent even when data is present',
        () {
      final interceptor = FlightRecorderDioInterceptor();
      final options = _options(method: 'POST', data: {'name': 'Jane'});
      interceptor.onRequest(options, RequestInterceptorHandler());

      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {'id': 1},
      );
      interceptor.onResponse(response, ResponseInterceptorHandler());

      final metadata = FlightRecorder.debugEvents.single.metadata;
      expect(metadata.containsKey('requestBody'), isFalse);
      expect(metadata.containsKey('responseBody'), isFalse);
    });

    test('captures the request body once explicitly enabled', () {
      final interceptor =
          FlightRecorderDioInterceptor(captureRequestBody: true);
      final options = _options(method: 'POST', data: {'name': 'Jane'});
      interceptor.onRequest(options, RequestInterceptorHandler());

      final response =
          Response<dynamic>(requestOptions: options, statusCode: 200);
      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(
        FlightRecorder.debugEvents.single.metadata['requestBody'],
        {'name': 'Jane'},
      );
    });

    test('captures the response body once explicitly enabled', () {
      final interceptor =
          FlightRecorderDioInterceptor(captureResponseBody: true);
      final options = _options();
      interceptor.onRequest(options, RequestInterceptorHandler());

      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {'id': 1},
      );
      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(
        FlightRecorder.debugEvents.single.metadata['responseBody'],
        {'id': 1},
      );
    });

    test('a captured body still gets masked by the core sanitizer', () {
      final interceptor =
          FlightRecorderDioInterceptor(captureRequestBody: true);
      final options = _options(
        method: 'POST',
        data: {'email': 'jane@example.com', 'password': 'hunter2'},
      );
      interceptor.onRequest(options, RequestInterceptorHandler());

      final response =
          Response<dynamic>(requestOptions: options, statusCode: 200);
      interceptor.onResponse(response, ResponseInterceptorHandler());

      final body =
          FlightRecorder.debugEvents.single.metadata['requestBody'] as Map;
      expect(body['email'], 'jane@example.com');
      expect(body['password'], '***');
    });
  });

  group('URL sanitization', () {
    test('masks sensitive query parameters by default', () {
      final interceptor = FlightRecorderDioInterceptor();
      final options = _options(
        url: 'https://api.example.com/login?token=abc123&user=jane',
      );
      interceptor.onRequest(options, RequestInterceptorHandler());

      final response =
          Response<dynamic>(requestOptions: options, statusCode: 200);
      interceptor.onResponse(response, ResponseInterceptorHandler());

      final url = FlightRecorder.debugEvents.single.metadata['url'] as String;
      expect(url, contains('token=%2A%2A%2A'));
      expect(url, contains('user=jane'));
      expect(url, isNot(contains('abc123')));
    });

    test('honors a custom sensitiveQueryParams set', () {
      final interceptor = FlightRecorderDioInterceptor(
        sensitiveQueryParams: {'secret'},
      );
      final options = _options(
        url: 'https://api.example.com/login?secret=abc&token=kept',
      );
      interceptor.onRequest(options, RequestInterceptorHandler());

      final response =
          Response<dynamic>(requestOptions: options, statusCode: 200);
      interceptor.onResponse(response, ResponseInterceptorHandler());

      final url = FlightRecorder.debugEvents.single.metadata['url'] as String;
      expect(url, isNot(contains('abc')));
      expect(url, contains('token=kept'));
    });

    test('leaves a URL with no query parameters untouched', () {
      final interceptor = FlightRecorderDioInterceptor();
      final options = _options(url: 'https://api.example.com/profile');
      interceptor.onRequest(options, RequestInterceptorHandler());

      final response =
          Response<dynamic>(requestOptions: options, statusCode: 200);
      interceptor.onResponse(response, ResponseInterceptorHandler());

      expect(
        FlightRecorder.debugEvents.single.metadata['url'],
        'https://api.example.com/profile',
      );
    });
  });

  group('uninitialized recorder', () {
    test('does not throw when FlightRecorder has not been initialized', () {
      FlightRecorder.resetForTest();
      final interceptor = FlightRecorderDioInterceptor();
      final options = _options();

      expect(
        () => interceptor.onRequest(options, RequestInterceptorHandler()),
        returnsNormally,
      );
      final response =
          Response<dynamic>(requestOptions: options, statusCode: 200);
      expect(
        () => interceptor.onResponse(response, ResponseInterceptorHandler()),
        returnsNormally,
      );
    });
  });
}
