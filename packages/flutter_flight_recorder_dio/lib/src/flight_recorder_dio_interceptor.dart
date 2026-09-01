import 'package:dio/dio.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';

const String _startTimeExtraKey = '_flutter_flight_recorder_start_time';

/// The [RequestOptions.extra] key this interceptor reads to explicitly
/// correlate a request with other recorded events — e.g. the user action
/// that triggered it. Set it on the request you want correlated:
///
/// ```dart
/// final id = FlightRecorder.newCorrelationId();
/// FlightRecorder.recordAction('save_tapped', correlationId: id);
/// await dio.patch(
///   '/profile',
///   options: Options(extra: {flightRecorderCorrelationIdKey: id}),
/// );
/// ```
///
/// Optional and purely additive — a request with no such key recorded
/// exactly as it always has, with `correlationId: null`. This is
/// explicit, per-request propagation only: nothing here reads ambient
/// state or infers a correlation id that wasn't set on the request
/// itself.
const String flightRecorderCorrelationIdKey = 'flightRecorderCorrelationId';

/// Records Dio HTTP requests into the flight recorder timeline.
///
/// ```dart
/// dio.interceptors.add(FlightRecorderDioInterceptor());
/// ```
///
/// One network event is recorded per request, when it finishes (success
/// or failure) — not a separate "started" event — carrying method, a
/// sanitized URL, timestamp, duration, status code, and error type
/// together in a single event.
///
/// Request and response bodies are **disabled by default**. Enable
/// [captureRequestBody] / [captureResponseBody] explicitly if you need
/// them. When captured, a body still passes through
/// `FlightRecorder`'s own metadata sanitization — the same default
/// sensitive-key masking used everywhere else in this package — so a
/// nested `password` field in a JSON body, for example, is still masked.
///
/// Query parameters whose key matches [sensitiveQueryParams]
/// (case-insensitive; defaults to [defaultSensitiveKeys]) are masked in
/// the recorded URL. This is the one part of what's recorded that this
/// interceptor sanitizes itself, rather than relying on
/// `FlightRecorder`'s generic metadata sanitizer — a URL is a single
/// opaque string to that sanitizer, not a map it can walk.
///
/// Recording is silently skipped if `FlightRecorder.init()` hasn't run
/// yet, the same as the navigation and lifecycle observers in the core
/// package — this interceptor can be constructed and attached to a
/// [Dio] instance before the app has necessarily initialized the
/// recorder.
class FlightRecorderDioInterceptor extends Interceptor {
  FlightRecorderDioInterceptor({
    this.captureRequestBody = false,
    this.captureResponseBody = false,
    this.sensitiveQueryParams = defaultSensitiveKeys,
  });

  final bool captureRequestBody;
  final bool captureResponseBody;
  final Set<String> sensitiveQueryParams;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    options.extra[_startTimeExtraKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _record(
      options: response.requestOptions,
      statusCode: response.statusCode,
      responseData: response.data,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(
      options: err.requestOptions,
      statusCode: err.response?.statusCode,
      responseData: err.response?.data,
      errorType: err.type.name,
    );
    handler.next(err);
  }

  void _record({
    required RequestOptions options,
    int? statusCode,
    Object? responseData,
    String? errorType,
  }) {
    if (!FlightRecorder.isInitialized) return;

    final startTime = options.extra[_startTimeExtraKey];
    final durationMs = startTime is DateTime
        ? DateTime.now().difference(startTime).inMilliseconds
        : null;
    final correlationId = options.extra[flightRecorderCorrelationIdKey];

    FlightRecorder.recordNetwork(
      '${options.method} ${options.uri.path}',
      metadata: {
        'method': options.method,
        'url': _sanitizeUri(options.uri).toString(),
        if (statusCode != null) 'statusCode': statusCode,
        if (durationMs != null) 'durationMs': durationMs,
        if (errorType != null) 'errorType': errorType,
        if (captureRequestBody && options.data != null)
          'requestBody': options.data,
        if (captureResponseBody && responseData != null)
          'responseBody': responseData,
      },
      correlationId: correlationId is String ? correlationId : null,
    );
  }

  Uri _sanitizeUri(Uri uri) {
    if (uri.queryParameters.isEmpty) return uri;
    final sanitized = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      sanitized[key] =
          sensitiveQueryParams.contains(key.toLowerCase()) ? '***' : value;
    });
    return uri.replace(queryParameters: sanitized);
  }
}
