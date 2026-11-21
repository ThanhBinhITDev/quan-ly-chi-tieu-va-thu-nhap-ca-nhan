import 'package:dio/dio.dart';

import 'package:android/core/config/app_config.dart';
import 'package:android/core/error/app_exception.dart';
import 'package:android/data/session/session_store.dart';

/// Gọi Supabase Auth trực tiếp (contract mục 3). API của chúng ta chỉ xác thực
/// JWT, không có endpoint đăng nhập riêng.
class AuthApi {
  AuthApi({required this.store, Dio? dio, Dio? apiDio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.supabaseUrl,
                connectTimeout: AppConfig.connectTimeout,
                receiveTimeout: AppConfig.receiveTimeout,
                headers: {
                  'apikey': AppConfig.supabaseAnonKey,
                  'Content-Type': 'application/json',
                },
              ),
            ),
        _apiDio = apiDio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: AppConfig.connectTimeout,
                receiveTimeout: AppConfig.receiveTimeout,
                headers: const {'Content-Type': 'application/json'},
              ),
            );

  final SessionStore store;
  final Dio _dio;

  /// Client trỏ vào API của mình (không phải Supabase), dùng cho dev login.
  final Dio _apiDio;

  /// Đăng nhập qua `POST /v1/dev/login` — endpoint chỉ mở ở server dev.
  Future<AuthSession> signInDev({
    required String email,
    required String password,
  }) async {
    return _postDev('/v1/dev/login', {
      'email': email,
      'password': password,
    });
  }

  /// Đăng ký dev local qua `POST /v1/dev/register` — chỉ server dev.
  Future<AuthSession> signUpDev({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return _postDev('/v1/dev/register', {
      'email': email,
      'password': password,
      'display_name': ?displayName,
    });
  }

  Future<AuthSession> _postDev(String path, Map<String, dynamic> data) async {
    try {
      final response = await _apiDio.post<Map<String, dynamic>>(path, data: data);
      return await _saveSession(response.data ?? const {});
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map) {
        final nested = body['error'];
        if (nested is Map && nested['message'] is String) {
          throw AppException(
            code: ApiErrorCode.unauthenticated,
            message: nested['message'] as String,
          );
        }
      }
      throw mapDioError(error);
    }
  }

  /// Đăng nhập bằng email + mật khẩu.
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/auth/v1/token',
      query: {'grant_type': 'password'},
      data: {'email': email, 'password': password},
    );
    return _saveSession(response);
  }

  /// Đăng ký tài khoản mới. Supabase có thể yêu cầu xác nhận email trước khi
  /// đăng nhập được, khi đó `session` là null.
  Future<AuthSession?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await _post(
      '/auth/v1/signup',
      data: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'data': {'display_name': displayName},
      },
    );
    final session = response['session'];
    if (session == null) return null;
    return _saveSession(response);
  }

  /// Gia hạn access token bằng refresh token.
  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _post(
      '/auth/v1/token',
      query: {'grant_type': 'refresh_token'},
      data: {'refresh_token': refreshToken},
    );
    return _saveSession(response);
  }

  Future<void> signOut() => store.clear();

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        queryParameters: query,
        data: data,
      );
      return response.data ?? const {};
    } catch (error) {
      throw _mapAuthError(error);
    }
  }

  /// Supabase Auth trả lỗi theo định dạng riêng (message/hint/error_description),
  /// không phải `{ error: { code } }` như API của mình. Dịch lại cho dễ hiểu.
  Object _mapAuthError(Object error) {
    if (error is! DioException) return mapDioError(error);
    final mapped = mapDioError(error);
    final body = error.response?.data;
    String? raw;
    if (body is Map) {
      raw = (body['message'] ?? body['error_description'] ?? body['msg'])
          as String?;
    }
    if (raw == null || raw.isEmpty) return mapped;
    final lower = raw.toLowerCase();
    if (lower.contains('invalid api key')) {
      return const AppException(
        code: ApiErrorCode.unauthenticated,
        message: 'Cấu hình Supabase chưa đúng (anon key không hợp lệ).',
      );
    }
    if (lower.contains('invalid login credentials')) {
      return const AppException(
        code: ApiErrorCode.unauthenticated,
        message: 'Email hoặc mật khẩu không đúng.',
      );
    }
    if (lower.contains('email not confirmed')) {
      return const AppException(
        code: ApiErrorCode.unauthenticated,
        message: 'Email chưa xác nhận. Kiểm tra hộp thư rồi thử lại.',
      );
    }
    if (lower.contains('user already registered')) {
      return const AppException(
        code: ApiErrorCode.validationFailed,
        message: 'Email này đã có tài khoản. Hãy đăng nhập.',
      );
    }
    if (lower.contains('password') && lower.contains('characters')) {
      return const AppException(
        code: ApiErrorCode.validationFailed,
        message: 'Mật khẩu quá ngắn, cần ít nhất 6 ký tự.',
      );
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return const AppException(
        code: ApiErrorCode.rateLimited,
        message: 'Bạn thử quá nhiều lần. Chờ một lát rồi thử lại.',
      );
    }
    return mapped;
  }

  Future<AuthSession> _saveSession(Map<String, dynamic> body) async {
    final accessToken = body['access_token'] as String?;
    // Dev login không phát refresh token: token sống 12 giờ và hết hạn thì
    // đăng nhập lại. Supabase thì luôn có.
    final refreshToken = (body['refresh_token'] as String?) ?? '';
    if (accessToken == null) {
      // Supabase trả lỗi trong body với status 200 ở vài trường hợp.
      final message = body['msg'] ?? body['error_description'] ?? body['error'];
      throw AppException(
        code: ApiErrorCode.unauthenticated,
        message: message is String
            ? message
            : 'Đăng nhập thất bại. Kiểm tra email và mật khẩu.',
      );
    }

    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
    final user = body['user'];
    final session = AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      userId: user is Map ? user['id'] as String? : null,
      email: user is Map ? user['email'] as String? : null,
    );
    await store.write(session);
    return session;
  }
}