import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_diag_log.dart';

class AuthUserPayload {
  const AuthUserPayload(
      {required this.id, required this.email, required this.name});
  final String id;
  final String email;
  final String name;
}

sealed class AuthApiResult {
  const AuthApiResult();
}

class AuthApiSuccess extends AuthApiResult {
  const AuthApiSuccess({required this.token, required this.user});
  final String token;
  final AuthUserPayload user;
}

class AuthApiFailure extends AuthApiResult {
  const AuthApiFailure({
    required this.statusCode,
    required this.errorKey,
    this.message,
    this.debugBodySnippet,
    this.fieldErrors = const [],
  });
  final int statusCode;
  final String errorKey;
  final String? message;

  /// First chars of raw body when JSON parse failed (empty if none).
  final String? debugBodySnippet;

  /// Parsed from `fields: [{field, message}]` when provided by the API.
  final List<String> fieldErrors;
}

class AuthApiService {
  AuthApiService({String? baseUrl})
      : _origin = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  static const _requestTimeout = Duration(seconds: 20);

  final String _origin;

  Uri _u(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_origin$p');
  }

  AuthApiFailure _failureFromCatch(Object e, String verb, Uri uri) {
    final str = e.toString().toLowerCase();
    final looksNet = e is SocketException ||
        e is HttpException ||
        e is TimeoutException ||
        str.contains('socket') ||
        str.contains('timed out') ||
        str.contains('network') ||
        str.contains('connection');
    if (looksNet) {
      return AuthApiFailure(
          statusCode: 0, errorKey: 'network_error', message: e.toString());
    }
    return AuthApiFailure(
        statusCode: 0, errorKey: 'unknown', message: e.toString());
  }

  Future<AuthApiResult> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final uri = _u('/api/auth/register');
    try {
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
              'name': name.trim()
            }),
          )
          .timeout(_requestTimeout);
      AppDiagLog.verbose('Login response: ${res.statusCode} ${res.body}');
      return _parseBody(res.statusCode, res.body);
    } catch (e, st) {
      AppDiagLog.verbose('register exception: $e\n$st');
      return _failureFromCatch(e, 'POST /api/auth/register', uri);
    }
  }

  Future<AuthApiResult> login({
    required String email,
    required String password,
  }) async {
    final uri = _u('/api/auth/login');
    try {
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(_requestTimeout);
      AppDiagLog.verbose('Login response: ${res.statusCode} ${res.body}');
      return _parseBody(res.statusCode, res.body);
    } catch (e, st) {
      AppDiagLog.verbose('login exception: $e\n$st');
      return _failureFromCatch(e, 'POST /api/auth/login', uri);
    }
  }

  Future<AuthApiResult> loginWithApple({
    required String identityToken,
    String? authorizationCode,
    String? userIdentifier,
    String? email,
    String? name,
  }) async {
    final uri = _u('/api/auth/apple');
    try {
      final body = <String, String>{
        'identityToken': identityToken.trim(),
        if (authorizationCode != null && authorizationCode.trim().isNotEmpty)
          'authorizationCode': authorizationCode.trim(),
        if (userIdentifier != null && userIdentifier.trim().isNotEmpty)
          'userIdentifier': userIdentifier.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      };
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      AppDiagLog.verbose('Apple auth response: ${res.statusCode} ${res.body}');
      return _parseBody(res.statusCode, res.body);
    } catch (e, st) {
      AppDiagLog.verbose('apple auth exception: $e\n$st');
      return _failureFromCatch(e, 'POST /api/auth/apple', uri);
    }
  }

  Future<AuthApiResult> loginWithGoogle({required String idToken}) async {
    final uri = _u('/api/auth/google');
    try {
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'idToken': idToken.trim()}),
          )
          .timeout(_requestTimeout);
      AppDiagLog.verbose('Google auth response: ${res.statusCode} ${res.body}');
      return _parseBody(res.statusCode, res.body);
    } catch (e, st) {
      AppDiagLog.verbose('google auth exception: $e\n$st');
      return _failureFromCatch(e, 'POST /api/auth/google', uri);
    }
  }

  Future<AuthApiResult> loginWithWeChat({required String code}) async {
    final uri = _u('/api/auth/wechat');
    try {
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'code': code.trim()}),
          )
          .timeout(_requestTimeout);
      AppDiagLog.verbose('WeChat auth response: ${res.statusCode} ${res.body}');
      return _parseBody(res.statusCode, res.body);
    } catch (e, st) {
      AppDiagLog.verbose('wechat auth exception: $e\n$st');
      return _failureFromCatch(e, 'POST /api/auth/wechat', uri);
    }
  }

  static Map<String, dynamic>? _asJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return null;
  }

  static String _str(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  static List<String> _fieldErrors(dynamic raw) {
    if (raw is! List) return [];
    final out = <String>[];
    for (final e in raw) {
      if (e is Map) {
        final field = _str(e['field']);
        final msg = _str(e['message']);
        if (field.isNotEmpty && msg.isNotEmpty) {
          out.add('$field: $msg');
        } else if (msg.isNotEmpty) {
          out.add(msg);
        }
      }
    }
    return out;
  }

  AuthApiResult _parseBody(int status, String bodyText) {
    final trimmed = bodyText.trimLeft();
    final noBom = trimmed.startsWith('\ufeff') ? trimmed.substring(1) : trimmed;

    Object? decoded;
    try {
      decoded = jsonDecode(noBom.isEmpty ? '{}' : noBom);
    } catch (_) {
      final clip = noBom.length > 120 ? '${noBom.substring(0, 120)}…' : noBom;
      final keyByStatus = status >= 500
          ? 'server_error'
          : status == 401
              ? 'invalid_credentials'
              : 'bad_payload';
      return AuthApiFailure(
        statusCode: status,
        errorKey: keyByStatus,
        message: clip.isEmpty ? 'Non-JSON response' : clip,
        debugBodySnippet: clip.isEmpty ? null : clip,
      );
    }

    final map = _asJsonMap(decoded);
    if (map == null) {
      return AuthApiFailure(
          statusCode: status,
          errorKey: 'bad_payload',
          message: 'not_a_json_object');
    }

    final tokenRaw = map['token'];
    final token = tokenRaw is String
        ? tokenRaw
        : (tokenRaw != null ? tokenRaw.toString() : '');
    final userMap = _asJsonMap(map['user']);
    final fieldErrs = _fieldErrors(map['fields']);

    if (status >= 200 &&
        status < 300 &&
        map['ok'] != false &&
        token.isNotEmpty &&
        userMap != null) {
      final id = _str(userMap['id']);
      final email = _str(userMap['email']);
      final name = _str(userMap['name']);
      if (id.isNotEmpty && email.isNotEmpty) {
        return AuthApiSuccess(
          token: token,
          user: AuthUserPayload(
              id: id,
              email: email,
              name: name.isEmpty ? email.split('@').first : name),
        );
      }
    }

    final err = map['error']?.toString() ?? 'unknown';
    final msg = map['message']?.toString();

    if (err == 'unauthorized_admin_token') {
      return AuthApiFailure(
          statusCode: status,
          errorKey: err,
          message: msg,
          fieldErrors: fieldErrs);
    }
    if ((status == 401 || status == 403) && err != 'account_suspended') {
      return AuthApiFailure(
          statusCode: status,
          errorKey: 'invalid_credentials',
          message: msg,
          fieldErrors: fieldErrs);
    }
    if (status == 409 || err == 'email_taken') {
      return AuthApiFailure(
          statusCode: status,
          errorKey: 'email_taken',
          message: msg,
          fieldErrors: fieldErrs);
    }

    final effectiveKey = status == 422
        ? 'validation_error'
        : (status >= 500 ? 'server_error' : err);

    return AuthApiFailure(
      statusCode: status,
      errorKey: effectiveKey,
      message: msg,
      debugBodySnippet: fieldErrs.isEmpty ? null : fieldErrs.join('; '),
      fieldErrors: fieldErrs,
    );
  }
}
