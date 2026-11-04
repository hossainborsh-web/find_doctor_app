import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../supabase_config.dart';

// ===========================================================================
// Supabase over HTTPS (sign-in + database), using only the `http` package.
//
// * CloudAuth   – sign up, sign in, sign out, password reset, keeps the
//                 session on this device and refreshes it before it expires.
// * SupaRest    – reads and writes tables through Supabase's REST API. Every
//                 request carries the signed-in person's token, so the
//                 database's security rules decide what they may see/change.
// ===========================================================================

/// The signed-in person (from Supabase Auth).
class CloudUser {
  const CloudUser({required this.uid, required this.email, this.displayName});

  final String uid;
  final String email;
  final String? displayName;

  factory CloudUser.fromJson(Map<String, dynamic> json) {
    final meta = json['user_metadata'] as Map<String, dynamic>? ?? const {};
    final doc = meta['doc'] as Map<String, dynamic>? ?? const {};
    return CloudUser(
      uid: json['id'] as String? ?? '',
      email: (json['email'] as String? ?? '').toLowerCase(),
      displayName: meta['full_name'] as String? ?? doc['fullName'] as String?,
    );
  }
}

/// A signed-in session: tokens plus who it belongs to.
class CloudSessionTokens {
  CloudSessionTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  String accessToken;
  String refreshToken;
  DateTime expiresAt;
  CloudUser user;

  factory CloudSessionTokens.fromJson(Map<String, dynamic> json) {
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    return CloudSessionTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      user: CloudUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  bool get expiresSoon =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 60)));
}

/// A sign-in problem. [code] is a short name the screens check
/// (e.g. 'email-already-in-use', 'invalid-credential').
class CloudAuthException implements Exception {
  const CloudAuthException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => message ?? code;
}

/// A database problem. [code]: 'permission-denied', 'not-found',
/// 'already-exists', 'unavailable', 'unauthenticated' or 'unknown'.
class CloudDbException implements Exception {
  const CloudDbException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

const _timeout = Duration(seconds: 20);
final http.Client _client = http.Client();

Uri _url(String path, [String? query]) {
  final base = SupabaseConfig.url.endsWith('/')
      ? SupabaseConfig.url.substring(0, SupabaseConfig.url.length - 1)
      : SupabaseConfig.url;
  return Uri.parse(query == null || query.isEmpty
      ? '$base$path'
      : '$base$path?$query');
}

Map<String, String> _headers([String? token]) => {
      'apikey': SupabaseConfig.anonKey,
      'Authorization': 'Bearer ${token ?? SupabaseConfig.anonKey}',
      'Content-Type': 'application/json',
    };

bool _isNetworkError(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    error is http.ClientException ||
    error is HandshakeException;

// ===========================================================================
// Auth
// ===========================================================================

class CloudAuth extends ChangeNotifier {
  CloudAuth._();

  static final CloudAuth instance = CloudAuth._();
  static const _storeKey = 'find_doctor_supabase_session_v1';

  CloudSessionTokens? _session;
  Future<CloudSessionTokens?>? _refreshing;

  CloudUser? get currentUser => _session?.user;

  /// Restores the saved session (if any). Call once at start-up.
  Future<CloudUser?> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _session = CloudSessionTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        user: CloudUser(
          uid: json['uid'] as String,
          email: json['email'] as String,
          displayName: json['displayName'] as String?,
        ),
      );
      if (_session!.expiresSoon) {
        try {
          await _refresh();
        } on CloudAuthException catch (error) {
          if (error.code != 'network-request-failed') {
            await _clear();
          }
        }
      }
    } catch (error) {
      debugPrint('Find Doctor: saved sign-in unreadable: $error');
      await _clear();
    }
    return currentUser;
  }

  /// A valid access token for requests (refreshed when needed), or null
  /// when nobody is signed in.
  Future<String?> accessToken() async {
    final session = _session;
    if (session == null) return null;
    if (session.expiresSoon) {
      try {
        final fresh = await _refresh();
        return fresh?.accessToken;
      } on CloudAuthException catch (error) {
        if (error.code == 'network-request-failed') return session.accessToken;
        rethrow;
      }
    }
    return session.accessToken;
  }

  /// Forces a token refresh (after the server said the token expired).
  Future<String?> refreshNow() async => (await _refresh())?.accessToken;

  Future<CloudSessionTokens?> _refresh() {
    return _refreshing ??= () async {
      try {
        final session = _session;
        if (session == null) return null;
        final fresh = await refreshSession(session.refreshToken);
        _session = fresh;
        await _save();
        return fresh;
      } on CloudAuthException catch (error) {
        if (error.code != 'network-request-failed') {
          // The saved sign-in is no longer valid: sign out locally.
          await _clear();
          notifyListeners();
        }
        rethrow;
      } finally {
        _refreshing = null;
      }
    }();
  }

  /// Creates a sign-in. [data] is stored with it (the sign-up trigger uses
  /// data['doc'] to make the profile). Returns the new user; signs in too
  /// when the project doesn't require email confirmation.
  Future<CloudUser> createUser({
    required String email,
    required String password,
    Map<String, dynamic> data = const {},
  }) async {
    final json = await _authPost('/auth/v1/signup',
        {'email': email, 'password': password, 'data': data});
    if (json['access_token'] != null) {
      _session = CloudSessionTokens.fromJson(json);
      await _save();
      notifyListeners();
      return _session!.user;
    }
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    return CloudUser.fromJson(user);
  }

  Future<CloudUser> signIn({
    required String email,
    required String password,
  }) async {
    _session = await signInRaw(email, password);
    await _save();
    notifyListeners();
    return _session!.user;
  }

  Future<void> signOut() async {
    final token = _session?.accessToken;
    await _clear();
    notifyListeners();
    if (token != null) {
      unawaited(_client
          .post(_url('/auth/v1/logout'), headers: _headers(token))
          .timeout(_timeout)
          .then((_) {}, onError: (_) {}));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _authPost('/auth/v1/recover', {'email': email});
  }

  /// Checks [currentPassword], then sets [newPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const CloudAuthException('requires-recent-login');
    }
    await signInRaw(user.email, currentPassword);
    final token = await accessToken();
    final http.Response response;
    try {
      response = await _client
          .put(_url('/auth/v1/user'),
              headers: _headers(token), body: jsonEncode({'password': newPassword}))
          .timeout(_timeout);
    } catch (error) {
      if (_isNetworkError(error)) {
        throw const CloudAuthException('network-request-failed');
      }
      rethrow;
    }
    if (response.statusCode >= 300) throw _authError(response);
  }

  Future<void> _save() async {
    final session = _session;
    if (session == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storeKey,
      jsonEncode({
        'accessToken': session.accessToken,
        'refreshToken': session.refreshToken,
        'expiresAt': session.expiresAt.toIso8601String(),
        'uid': session.user.uid,
        'email': session.user.email,
        'displayName': session.user.displayName,
      }),
    );
  }

  Future<void> _clear() async {
    _session = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storeKey);
    } catch (_) {}
  }

  // ------------------------------------------------- sessions for others

  /// Signs in without touching this device's saved session (used by the
  /// demo loader to act as each demo person).
  static Future<CloudSessionTokens> signInRaw(
      String email, String password) async {
    final json = await _authPost('/auth/v1/token', {
      'email': email,
      'password': password,
    }, query: 'grant_type=password');
    return CloudSessionTokens.fromJson(json);
  }

  /// Signs up without touching this device's saved session. Returns null
  /// when the project requires email confirmation (no session yet).
  static Future<CloudSessionTokens?> signUpRaw(
      String email, String password, Map<String, dynamic> data) async {
    final json = await _authPost('/auth/v1/signup',
        {'email': email, 'password': password, 'data': data});
    if (json['access_token'] == null) return null;
    return CloudSessionTokens.fromJson(json);
  }

  static Future<CloudSessionTokens> refreshSession(String refreshToken) async {
    final json = await _authPost(
        '/auth/v1/token', {'refresh_token': refreshToken},
        query: 'grant_type=refresh_token');
    return CloudSessionTokens.fromJson(json);
  }

  static Future<Map<String, dynamic>> _authPost(
      String path, Map<String, dynamic> body,
      {String? query}) async {
    final http.Response response;
    try {
      response = await _client
          .post(_url(path, query), headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);
    } catch (error) {
      if (_isNetworkError(error)) {
        throw const CloudAuthException('network-request-failed');
      }
      rethrow;
    }
    if (response.statusCode >= 300) throw _authError(response);
    if (response.body.isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  static CloudAuthException _authError(http.Response response) {
    var code = '';
    var message = 'HTTP ${response.statusCode}';
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      code = (json['error_code'] ?? json['error'] ?? '').toString();
      message = (json['msg'] ?? json['message'] ?? json['error_description'] ??
              message)
          .toString();
    } catch (_) {}
    final lower = '$code $message'.toLowerCase();
    String mapped;
    if (lower.contains('already') || code == 'email_exists') {
      mapped = 'email-already-in-use';
    } else if (code == 'invalid_credentials' ||
        lower.contains('invalid login') ||
        code == 'invalid_grant') {
      mapped = 'invalid-credential';
    } else if (code == 'refresh_token_not_found' ||
        code == 'refresh_token_already_used' ||
        code == 'session_not_found' ||
        code == 'user_not_found') {
      mapped = 'user-token-expired';
    } else if (code == 'weak_password' || lower.contains('password should')) {
      mapped = 'weak-password';
    } else if (code == 'email_not_confirmed') {
      mapped = 'email-not-confirmed';
    } else if (code == 'email_address_invalid' ||
        lower.contains('invalid format') ||
        lower.contains('email address') && lower.contains('invalid')) {
      mapped = 'invalid-email';
    } else if (response.statusCode == 429 || lower.contains('rate limit')) {
      mapped = 'too-many-requests';
    } else if (code == 'signup_disabled' || code == 'email_provider_disabled') {
      mapped = 'operation-not-allowed';
    } else if (code == 'user_banned') {
      mapped = 'user-disabled';
    } else {
      mapped = code.isEmpty ? 'unknown' : code;
    }
    return CloudAuthException(mapped, message);
  }
}

// ===========================================================================
// REST (tables and functions)
// ===========================================================================

/// A token source: the signed-in person by default, or a fixed session
/// (demo loader acting as someone else).
typedef TokenSource = Future<String?> Function();

class SupaRest {
  SupaRest._();

  static Future<String?> _defaultToken() => CloudAuth.instance.accessToken();

  /// GET /rest/v1/[table]?[query]. Pages through results 1000 at a time.
  static Future<List<Map<String, dynamic>>> select(
    String table,
    String query, {
    TokenSource? token,
  }) async {
    const page = 1000;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final response = await _send(
        'GET',
        '/rest/v1/$table',
        query: [
          if (query.isNotEmpty) query,
          'order=id.asc',
          'limit=$page',
          'offset=$offset',
        ].join('&'),
        token: token,
      );
      final list = jsonDecode(response.body) as List<dynamic>;
      rows.addAll(list.cast<Map<String, dynamic>>());
      if (list.length < page) break;
      offset += page;
    }
    return rows;
  }

  static Future<void> insert(String table, Map<String, dynamic> row,
      {TokenSource? token}) async {
    await _send('POST', '/rest/v1/$table',
        body: row, token: token, prefer: 'return=minimal');
  }

  static Future<void> delete(String table, String query,
      {TokenSource? token}) async {
    await _send('DELETE', '/rest/v1/$table',
        query: query, token: token, prefer: 'return=minimal');
  }

  static Future<void> rpc(String function, Map<String, dynamic> params,
      {TokenSource? token}) async {
    await _send('POST', '/rest/v1/rpc/$function', body: params, token: token);
  }

  static Future<http.Response> _send(
    String method,
    String path, {
    String? query,
    Object? body,
    TokenSource? token,
    String? prefer,
    bool retried = false,
  }) async {
    String? bearer;
    try {
      bearer = await (token ?? _defaultToken)();
    } on CloudAuthException catch (error) {
      // The saved sign-in expired for good: report it like any other
      // database problem, so callers that catch CloudDbException handle it.
      throw CloudDbException('unauthenticated',
          'Your sign-in has expired. Please sign in again. (${error.code})');
    }
    if (bearer == null) {
      throw const CloudDbException('unauthenticated', 'Please sign in first.');
    }
    final headers = _headers(bearer);
    if (prefer != null) headers['Prefer'] = prefer;
    final request = http.Request(method, _url(path, query))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body, toEncodable: _encodable);
    final http.Response response;
    try {
      response = await http.Response.fromStream(
          await _client.send(request).timeout(_timeout));
    } catch (error) {
      if (_isNetworkError(error)) {
        throw const CloudDbException(
            'unavailable', 'No internet connection. Check it and try again.');
      }
      rethrow;
    }
    if (response.statusCode < 300) return response;
    if (response.statusCode == 401 && token == null && !retried) {
      try {
        await CloudAuth.instance.refreshNow();
      } catch (_) {}
      return _send(method, path,
          query: query, body: body, token: token, prefer: prefer, retried: true);
    }
    throw _dbError(response);
  }

  static Object? _encodable(Object? value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is Set) return value.toList();
    return value.toString();
  }

  static CloudDbException _dbError(http.Response response) {
    var code = '';
    var message = 'HTTP ${response.statusCode}';
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      code = (json['code'] ?? '').toString();
      message = (json['message'] ?? message).toString();
    } catch (_) {}
    if (code == '23505' || response.statusCode == 409) {
      return CloudDbException('already-exists', message);
    }
    if (code == 'P0002') return CloudDbException('not-found', message);
    if (code == '42501' ||
        response.statusCode == 403 ||
        message.contains('row-level security')) {
      return CloudDbException('permission-denied', message);
    }
    if (response.statusCode == 401) {
      return CloudDbException('unauthenticated', message);
    }
    return CloudDbException('unknown', message);
  }
}
