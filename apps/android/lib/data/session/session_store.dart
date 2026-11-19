import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Phiên đăng nhập: access token để gọi API, refresh token để gia hạn.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.userId,
    this.email,
  });

  final String accessToken;
  final String refreshToken;

  /// Thời điểm access token hết hạn (giờ máy). Làm mới sớm 5 phút.
  final DateTime expiresAt;

  final String? userId;
  final String? email;

  bool get isExpiringSoon =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) =>
      AuthSession(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        expiresAt: expiresAt ?? this.expiresAt,
        userId: userId,
        email: email,
      );
}

/// Lưu phiên vào bộ nhớ bảo mật của hệ điều hành (Keychain/EncryptedSharedPrefs).
/// Không dùng `shared_preferences`: nơi đó lưu dạng plaintext.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kAccess = 'sf.access_token';
  static const _kRefresh = 'sf.refresh_token';
  static const _kExpires = 'sf.expires_at';
  static const _kUserId = 'sf.user_id';
  static const _kEmail = 'sf.email';

  Future<AuthSession?> read() async {
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    if (access == null || refresh == null) return null;

    final expiresRaw = await _storage.read(key: _kExpires);
    final expiresAt = DateTime.tryParse(expiresRaw ?? '');
    if (expiresAt == null) return null;

    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiresAt,
      userId: await _storage.read(key: _kUserId),
      email: await _storage.read(key: _kEmail),
    );
  }

  Future<void> write(AuthSession session) async {
    await _storage.write(key: _kAccess, value: session.accessToken);
    await _storage.write(key: _kRefresh, value: session.refreshToken);
    await _storage.write(
      key: _kExpires,
      value: session.expiresAt.toIso8601String(),
    );
    if (session.userId != null) {
      await _storage.write(key: _kUserId, value: session.userId);
    }
    if (session.email != null) {
      await _storage.write(key: _kEmail, value: session.email);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kExpires);
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kEmail);
  }
}