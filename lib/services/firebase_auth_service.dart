import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class FirebaseAuthUser {
  const FirebaseAuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.role,
    required this.managerLevel,
    required this.approved,
  });

  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;
  final String role;
  final String? managerLevel;
  final bool approved;
}

class FirebaseAuthServiceException implements Exception {
  const FirebaseAuthServiceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Firebase Authentication over HTTPS, usable by the Windows desktop app
/// without relying on the beta Firebase Windows native plugin.
class FirebaseAuthService {
  FirebaseAuthService({
    http.Client? client,
    FlutterSecureStorage? secureStorage,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _apiKey = apiKey ?? const String.fromEnvironment('FIREBASE_API_KEY');

  static final FirebaseAuthService instance = FirebaseAuthService();

  static const _refreshTokenKey = 'firebase_auth_refresh_token';
  static const _identityToolkitUrl =
      'https://identitytoolkit.googleapis.com/v1';
  static const _secureTokenUrl = 'https://securetoken.googleapis.com/v1/token';

  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  final String _apiKey;

  String? _refreshToken;
  String? _idToken;
  DateTime? _idTokenExpiresAt;
  FirebaseAuthUser? _currentUser;

  bool get isConfigured => _apiKey.trim().isNotEmpty;
  FirebaseAuthUser? get currentUser => _currentUser;

  Future<FirebaseAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    _requireConfiguration();
    final auth = await _postIdentityToolkit('accounts:signInWithPassword', {
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    });
    final session = _sessionFromAuthResponse(auth);
    final userRecord = await _lookupUser(session.idToken);
    final user = _userFromRecord(userRecord, session.idToken);

    if (!user.emailVerified) {
      try {
        await _sendVerificationEmail(session.idToken);
      } finally {
        await signOut();
      }
      throw const FirebaseAuthServiceException(
        'EMAIL_NOT_VERIFIED',
        'Verify your email first. We sent you a new verification link.',
      );
    }

    await _saveSession(session, user);
    return user;
  }

  Future<FirebaseAuthUser> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    _requireConfiguration();
    final auth = await _postIdentityToolkit('accounts:signUp', {
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    });
    var session = _sessionFromAuthResponse(auth);

    final updated = await _postIdentityToolkit('accounts:update', {
      'idToken': session.idToken,
      'displayName': displayName.trim(),
      'returnSecureToken': true,
    });
    session = _sessionFromAuthResponse(updated);
    await _sendVerificationEmail(session.idToken);

    final userRecord = await _lookupUser(session.idToken);
    return _userFromRecord(userRecord, session.idToken);
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    _requireConfiguration();
    await _postIdentityToolkit('accounts:sendOobCode', {
      'requestType': 'PASSWORD_RESET',
      'email': email.trim(),
    });
  }

  Future<void> sendVerificationEmail() async {
    _requireConfiguration();
    final token = await _freshIdToken();
    await _sendVerificationEmail(token);
  }

  Future<FirebaseAuthUser?> restoreSession() async {
    if (!isConfigured) return null;

    final storedRefreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (storedRefreshToken == null || storedRefreshToken.isEmpty) return null;

    try {
      final tokenResponse = await _refreshSession(storedRefreshToken);
      final token = tokenResponse['id_token'] as String;
      final userRecord = await _lookupUser(token);
      final user = _userFromRecord(userRecord, token);
      if (!user.emailVerified) {
        await signOut();
        return null;
      }

      final expiresIn = int.tryParse('${tokenResponse['expires_in']}') ?? 3600;
      await _saveSession(
        _AuthSession(
          idToken: token,
          refreshToken:
              tokenResponse['refresh_token'] as String? ?? storedRefreshToken,
          expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
        ),
        user,
      );
      return user;
    } on FirebaseAuthServiceException catch (error) {
      if (_isInvalidRefreshToken(error.code)) {
        await signOut();
        return null;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    _refreshToken = null;
    _idToken = null;
    _idTokenExpiresAt = null;
    _currentUser = null;
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  Future<String> getIdToken() => _freshIdToken();

  Future<String> _freshIdToken() async {
    final expiry = _idTokenExpiresAt;
    if (_idToken != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return _idToken!;
    }

    final refreshToken =
        _refreshToken ?? await _secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const FirebaseAuthServiceException(
        'NO_CURRENT_USER',
        'Sign in to continue.',
      );
    }

    final refreshed = await _refreshSession(refreshToken);
    final expiresIn = int.tryParse('${refreshed['expires_in']}') ?? 3600;
    _idToken = refreshed['id_token'] as String;
    _refreshToken = refreshed['refresh_token'] as String? ?? refreshToken;
    _idTokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    await _secureStorage.write(
      key: _refreshTokenKey,
      value: _refreshToken,
    );
    return _idToken!;
  }

  Future<Map<String, dynamic>> _refreshSession(String refreshToken) async {
    final uri = Uri.parse(_secureTokenUrl).replace(queryParameters: {
      'key': _apiKey,
    });
    try {
      final response = await _client.post(
        uri,
        headers: const {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      ).timeout(const Duration(seconds: 20));
      return _decodeResponse(response);
    } on TimeoutException {
      throw const FirebaseAuthServiceException(
        'NETWORK_TIMEOUT',
        'The sign-in service took too long to respond. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const FirebaseAuthServiceException(
        'NETWORK_ERROR',
        'Could not reach Firebase. Check your internet connection and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> _postIdentityToolkit(
    String operation,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_identityToolkitUrl/$operation').replace(
      queryParameters: {'key': _apiKey},
    );
    try {
      final response = await _client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      return _decodeResponse(response);
    } on TimeoutException {
      throw const FirebaseAuthServiceException(
        'NETWORK_TIMEOUT',
        'The sign-in service took too long to respond. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const FirebaseAuthServiceException(
        'NETWORK_ERROR',
        'Could not reach Firebase. Check your internet connection and try again.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> decoded;
    try {
      final json = jsonDecode(response.body);
      decoded = json is Map<String, dynamic> ? json : <String, dynamic>{};
    } on FormatException {
      decoded = <String, dynamic>{};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final error = decoded['error'];
    final rawCode = error is Map ? error['message']?.toString() : null;
    final code = rawCode?.split(RegExp(r'[: ]')).first ?? 'SERVICE_UNAVAILABLE';
    throw FirebaseAuthServiceException(code, _messageForCode(code));
  }

  Future<Map<String, dynamic>> _lookupUser(String idToken) async {
    final result = await _postIdentityToolkit('accounts:lookup', {
      'idToken': idToken,
    });
    final users = result['users'];
    if (users is! List || users.isEmpty || users.first is! Map) {
      throw const FirebaseAuthServiceException(
        'USER_RECORD_MISSING',
        'Firebase signed you in but did not return an account profile.',
      );
    }
    return Map<String, dynamic>.from(users.first as Map);
  }

  Future<void> _sendVerificationEmail(String idToken) async {
    await _postIdentityToolkit('accounts:sendOobCode', {
      'requestType': 'VERIFY_EMAIL',
      'idToken': idToken,
    });
  }

  _AuthSession _sessionFromAuthResponse(Map<String, dynamic> response) {
    final idToken = response['idToken'] as String?;
    final refreshToken = response['refreshToken'] as String?;
    if (idToken == null || refreshToken == null) {
      throw const FirebaseAuthServiceException(
        'INVALID_RESPONSE',
        'Firebase returned an incomplete sign-in response. Please try again.',
      );
    }
    final expiresIn = int.tryParse('${response['expiresIn']}') ?? 3600;
    return _AuthSession(
      idToken: idToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  FirebaseAuthUser _userFromRecord(
    Map<String, dynamic> record,
    String idToken,
  ) {
    final claims = _claimsFromIdToken(idToken);
    final role = _normaliseRole(claims['role']?.toString());
    return FirebaseAuthUser(
      id: record['localId']?.toString() ?? '',
      email: record['email']?.toString() ?? '',
      displayName: record['displayName']?.toString() ?? '',
      emailVerified: record['emailVerified'] as bool? ?? false,
      role: role,
      managerLevel: claims['managerLevel']?.toString(),
      approved: claims['approved'] == true,
    );
  }

  Map<String, dynamic> _claimsFromIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return const {};
      final bytes = base64Url.decode(base64Url.normalize(parts[1]));
      final payload = jsonDecode(utf8.decode(bytes));
      return payload is Map<String, dynamic> ? payload : const {};
    } on FormatException {
      return const {};
    }
  }

  String _normaliseRole(String? role) {
    switch (role?.trim().toLowerCase()) {
      case 'student': // legacy accounts are treated as patients
        return 'Patient';
      case 'doctor':
        return 'Doctor';
      case 'doctor manager':
      case 'doctormanager':
        return 'Doctor Manager';
      case 'manager':
        return 'Manager';
      case 'general manager':
      case 'generalmanager':
        return 'General Manager';
      default:
        return 'Patient';
    }
  }

  Future<void> _saveSession(_AuthSession session, FirebaseAuthUser user) async {
    _idToken = session.idToken;
    _refreshToken = session.refreshToken;
    _idTokenExpiresAt = session.expiresAt;
    _currentUser = user;
    await _secureStorage.write(
      key: _refreshTokenKey,
      value: session.refreshToken,
    );
  }

  void _requireConfiguration() {
    if (isConfigured) return;
    throw const FirebaseAuthServiceException(
      'FIREBASE_NOT_CONFIGURED',
      'Firebase is not configured. Start the app with --dart-define=FIREBASE_API_KEY=YOUR_WEB_API_KEY.',
    );
  }

  bool _isInvalidRefreshToken(String code) =>
      code == 'TOKEN_EXPIRED' ||
      code == 'INVALID_REFRESH_TOKEN' ||
      code == 'USER_NOT_FOUND' ||
      code == 'USER_DISABLED';

  String _messageForCode(String code) {
    switch (code) {
      case 'INVALID_LOGIN_CREDENTIALS':
      case 'EMAIL_NOT_FOUND':
      case 'INVALID_PASSWORD':
        return 'The email or password is incorrect.';
      case 'EMAIL_NOT_VERIFIED':
        return 'Verify your email first. We sent you a new verification link.';
      case 'EMAIL_EXISTS':
        return 'An account already exists for this email. Sign in instead.';
      case 'INVALID_EMAIL':
        return 'Enter a valid email address.';
      case 'WEAK_PASSWORD':
      case 'WEAK_PASSWORD : PASSWORD_DOES_NOT_MEET_REQUIREMENTS':
        return 'Choose a stronger password and try again.';
      case 'OPERATION_NOT_ALLOWED':
        return 'Email and password sign-in is disabled in Firebase Authentication.';
      case 'USER_DISABLED':
        return 'This account has been disabled. Contact your administrator.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Too many attempts. Wait a little and try again.';
      case 'NETWORK_ERROR':
        return 'Could not reach Firebase. Check your internet connection and try again.';
      case 'NETWORK_TIMEOUT':
        return 'The sign-in service took too long to respond. Check your connection and try again.';
      case 'API_KEY_INVALID':
      case 'PROJECT_NUMBER_MISMATCH':
        return 'The Firebase Web API key is invalid or belongs to another project.';
      default:
        return 'Firebase sign-in is temporarily unavailable. Please try again.';
    }
  }
}

class _AuthSession {
  const _AuthSession({
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;
}
