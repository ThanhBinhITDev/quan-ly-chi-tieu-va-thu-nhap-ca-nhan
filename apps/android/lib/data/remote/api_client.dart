import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:android/core/config/app_config.dart';
import 'package:android/core/error/app_exception.dart';
import 'package:android/data/remote/auth_api.dart';
import 'package:android/data/session/session_store.dart';

/// Client gọi API Student Finance.
///
/// - Gắn `Authorization: Bearer <access_token>` vào mọi request.
/// - Tự gia hạn token khi còn < 5 phút, và thử lại một lần nếu server trả 401.
/// - Đổi mọi lỗi thành [AppException] có câu tiếng Việt.
class ApiClient {
  ApiClient({
    required SessionStore store,
    AuthApi? authApi,
    Dio? dio,
    this.forcedToken,
  })  : _store = store,
        _authApi = authApi ?? AuthApi(store: store),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: AppConfig.connectTimeout,
                receiveTimeout: AppConfig.receiveTimeout,
                contentType: 'application/json',
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _validAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // 401 có thể do token vừa hết hạn giữa đường: làm mới rồi thử lại.
          final isAuthError = error.response?.statusCode == 401;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          if (isAuthError && !alreadyRetried) {
            try {
              await _refresh();
              final token = await _validAccessToken();
              final options = error.requestOptions;
              options.extra['retried'] = true;
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              final response = await _dio.fetch<dynamic>(options);
              handler.resolve(response);
              return;
            } catch (_) {
              // Làm mới thất bại: để lỗi 401 đi tiếp, UI sẽ đưa về đăng nhập.
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final SessionStore _store;
  final AuthApi _authApi;
  final Dio _dio;

  /// Token tiêm tường minh cho dev (xem `AppConfig.devAccessToken`).
  /// Có giá trị thì bỏ qua secure storage, không đọc/ghi gì thêm.
  final String? forcedToken;

  Future<String?> _validAccessToken() async {
    if (forcedToken != null && forcedToken!.isNotEmpty) return forcedToken;
    final session = await _store.read();
    if (session == null) return null;
    // Phiên dev login không có refresh token: dùng token tới khi hết hạn.
    if (session.refreshToken.isEmpty) return session.accessToken;
    if (!session.isExpiringSoon) return session.accessToken;
    try {
      final refreshed = await _authApi.refresh(session.refreshToken);
      return refreshed.accessToken;
    } catch (_) {
      return session.accessToken;
    }
  }

  Future<void> _refresh() async {
    final current = await _store.read();
    if (current != null && current.refreshToken.isEmpty) {
      throw const AppException(
        code: ApiErrorCode.unauthenticated,
        message: 'Phiên đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    if (forcedToken != null && forcedToken!.isNotEmpty) {
      // Token dev không gia hạn được; gọi lại API sẽ ra lỗi 401 thật.
      throw const AppException(
        code: ApiErrorCode.unauthenticated,
        message: 'Token dev không có refresh token.',
      );
    }
    final session = await _store.read();
    if (session == null) {
      throw const AppException(
        code: ApiErrorCode.unauthenticated,
        message: 'Chưa đăng nhập.',
      );
    }
    await _authApi.refresh(session.refreshToken);
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return _run(() => _dio.get<T>(path, queryParameters: query));
  }

  Future<T> post<T>(String path, {Object? data}) async {
    return _run(() => _dio.post<T>(path, data: data));
  }

  Future<T> patch<T>(String path, {Object? data}) async {
    return _run(() => _dio.patch<T>(path, data: data));
  }

  /// API không xoá cứng: `DELETE` nghĩa là xoá mềm và trả bản ghi đã xoá.
  Future<T> delete<T>(String path) async {
    return _run(() => _dio.delete<T>(path));
  }

  Future<T> put<T>(String path, {Object? data}) async {
    return _run(() => _dio.put<T>(path, data: data));
  }

  /// Tải bytes (ảnh đại diện). Trả `null` khi server trả 404 thay vì ném lỗi:
  /// "chưa có ảnh" là trạng thái bình thường, không phải sự cố.
  Future<Uint8List?> getBytes(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) return null;
      return Uint8List.fromList(data);
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 404) {
        return null;
      }
      throw mapDioError(error);
    }
  }

  Future<T> _run<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      final data = response.data;
      if (data == null) {
        throw const AppException(
          code: ApiErrorCode.internal,
          message: 'Máy chủ trả về dữ liệu rỗng.',
        );
      }
      return data;
    } catch (error) {
      throw mapDioError(error);
    }
  }
}