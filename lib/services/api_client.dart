import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session_manager.dart';
import 'protocol_logger_service.dart';

/// Shared JSON HTTP client with a **global 401 interceptor**.
///
/// Use this instead of bare `http.get/post/...` for any request that carries a
/// user Bearer JWT. On a `401 Unauthorized` the client:
///  * attempts a silent token refresh (only if a refresh flow is wired via
///    [AuthSessionManager]) and retries the request once with the new token;
///  * otherwise notifies [AuthSessionManager] (single-flight reset of the
///    session + redirect to the login screen + "session expired" dialog);
///  * still returns the 401 response so the caller keeps its existing
///    status-based handling (e.g. throwing a typed auth exception).
///
/// Requests that carry **no** Bearer token (pairing-token-only frame calls,
/// guest invite lookups, …) are never treated as session expiry — a 401 there
/// just returns to the caller unchanged.
class ApiClient {
  ApiClient({String? bearerToken, http.Client? inner})
    : _token = (bearerToken ?? '').trim(),
      _inner = inner ?? http.Client();

  String _token;
  final http.Client _inner;

  bool get hasToken => _token.trim().isNotEmpty;

  /// Rotate the stored token (used after a refresh).
  void setToken(String? token) => _token = (token ?? '').trim();

  void close() => _inner.close();

  Map<String, String> _effectiveHeaders(Map<String, String>? extra) {
    return <String, String>{
      'Accept': 'application/json',
      if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
      // Caller-supplied headers win (e.g. a per-request bearer override).
      ...?extra,
    };
  }

  static String? _encodeBody(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    return jsonEncode(body);
  }

  http.Request _buildJsonRequest(
    String method,
    Uri uri,
    Map<String, String>? headers,
    Object? body,
  ) {
    final req = http.Request(method, uri)
      ..headers.addAll(_effectiveHeaders(headers));
    final encoded = _encodeBody(body);
    if (encoded != null) {
      req.body = encoded;
      if (!req.headers.containsKey('Content-Type')) {
        req.headers['Content-Type'] = 'application/json';
      }
    }
    return req;
  }

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) => send(
    http.Request('GET', uri)..headers.addAll(_effectiveHeaders(headers)),
  );

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => send(_buildJsonRequest('POST', uri, headers, body));

  Future<http.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => send(_buildJsonRequest('PUT', uri, headers, body));

  Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => send(_buildJsonRequest('PATCH', uri, headers, body));

  Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) => send(_buildJsonRequest('DELETE', uri, headers, body));

  /// Send any [http.BaseRequest] (plain, JSON, or multipart) through the
  /// interceptor. Multipart requests must set their own `Authorization` header.
  Future<http.Response> send(http.BaseRequest base) async {
    var streamed = await _inner.send(base);

    if (streamed.statusCode == 401 && _isBearerAuthed(base)) {
      final refreshed = await AuthSessionManager.instance.attemptRefresh();
      if (refreshed != null && refreshed.trim().isNotEmpty) {
        // Free the rejected connection before retrying with the new token.
        await streamed.stream.drain<void>();
        setToken(refreshed);
        // Re-send the original request (multipart bodies included) with the
        // new Authorization header.
        base.headers['Authorization'] = 'Bearer $refreshed';
        streamed = await _inner.send(base);
      }

      if (streamed.statusCode == 401) {
        // Reset session + redirect to login (single-flight inside the manager).
        await AuthSessionManager.instance.handleUnauthorized();
      }
    }

    final res = await http.Response.fromStream(streamed);
    ProtocolLoggerService.instance.logApi(
      base.method,
      base.url.toString(),
      statusCode: res.statusCode,
    );
    return res;
  }

  /// Only a request that actually carries a user Bearer JWT can signal an
  /// expired *session*. Pairing-token-only calls are excluded so a bad frame
  /// token cannot log the user out.
  bool _isBearerAuthed(http.BaseRequest req) {
    final auth = (req.headers['Authorization'] ?? '').trim();
    const prefix = 'bearer ';
    return auth.toLowerCase().startsWith(prefix) && auth.length > prefix.length;
  }
}
