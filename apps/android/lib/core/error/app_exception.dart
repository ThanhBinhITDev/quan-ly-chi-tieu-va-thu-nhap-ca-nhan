import 'package:dio/dio.dart';

/// Mã lỗi API trả về trong `{ "error": { "code": ..., "message": ... } }`.
enum ApiErrorCode {
  unauthenticated,
  forbidden,
  notFound,
  validationFailed,
  ruleViolation,
  planLimit,
  syncConflict,
  rateLimited,
  internal,
  network,
  unknown;

  static ApiErrorCode parse(String? raw) {
    switch (raw) {
      case 'UNAUTHENTICATED':
        return ApiErrorCode.unauthenticated;
      case 'FORBIDDEN':
        return ApiErrorCode.forbidden;
      case 'NOT_FOUND':
        return ApiErrorCode.notFound;
      case 'VALIDATION_FAILED':
        return ApiErrorCode.validationFailed;
      case 'RULE_VIOLATION':
        return ApiErrorCode.ruleViolation;
      case 'PLAN_LIMIT':
        return ApiErrorCode.planLimit;
      case 'SYNC_CONFLICT':
        return ApiErrorCode.syncConflict;
      case 'RATE_LIMITED':
        return ApiErrorCode.rateLimited;
      case 'INTERNAL':
        return ApiErrorCode.internal;
      default:
        return ApiErrorCode.unknown;
    }
  }
}

/// Lỗi có kiểu, mang thông điệp tiếng Việt hiển thị được cho người dùng.
class AppException implements Exception {
  const AppException({
    required this.code,
    required this.message,
    this.serverRev,
  });

  final ApiErrorCode code;
  final String message;

  /// Với SYNC_CONFLICT: rev mới nhất trên server để client kéo lại.
  final int? serverRev;

  bool get isAuthFailure => code == ApiErrorCode.unauthenticated;
  bool get isConflict => code == ApiErrorCode.syncConflict;

  @override
  String toString() => message;
}

/// Đổi lỗi Dio thành [AppException] với câu tiếng Việt phù hợp.
AppException mapDioError(Object error) {
  if (error is AppException) return error;

  if (error is DioException) {
    // Không có phản hồi: mất mạng, sai địa chỉ, server tắt.
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const AppException(
        code: ApiErrorCode.network,
        message: 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      );
    }

    final response = error.response;
    if (response == null) {
      return const AppException(
        code: ApiErrorCode.network,
        message: 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      );
    }

    final body = response.data;
    String? rawCode;
    String? rawMessage;
    int? serverRev;
    if (body is Map) {
      final errorBody = body['error'];
      if (errorBody is Map) {
        rawCode = errorBody['code'] as String?;
        rawMessage = errorBody['message'] as String?;
        // API đặt `details` BÊN TRONG `error`, không ngang cấp.
        final details = errorBody['details'];
        if (details is Map && details['server_rev'] is int) {
          serverRev = details['server_rev'] as int;
        }
      }
    }

    final code = ApiErrorCode.parse(rawCode);
    return AppException(
      code: code,
      message: rawMessage ?? _fallbackMessage(code),
      serverRev: serverRev,
    );
  }

  return const AppException(
    code: ApiErrorCode.unknown,
    message: 'Đã xảy ra lỗi. Vui lòng thử lại.',
  );
}

String _fallbackMessage(ApiErrorCode code) {
  switch (code) {
    case ApiErrorCode.unauthenticated:
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    case ApiErrorCode.forbidden:
      return 'Bạn không có quyền thực hiện thao tác này.';
    case ApiErrorCode.notFound:
      return 'Không tìm thấy dữ liệu.';
    case ApiErrorCode.validationFailed:
      return 'Dữ liệu không hợp lệ.';
    case ApiErrorCode.ruleViolation:
      return 'Thao tác không hợp lệ.';
    case ApiErrorCode.planLimit:
      return 'Bạn đã đạt giới hạn của gói hiện tại.';
    case ApiErrorCode.syncConflict:
      return 'Dữ liệu đã thay đổi ở nơi khác. Đang tải lại...';
    case ApiErrorCode.rateLimited:
      return 'Bạn thao tác quá nhanh, vui lòng thử lại sau.';
    case ApiErrorCode.internal:
      return 'Máy chủ gặp sự cố. Vui lòng thử lại.';
    case ApiErrorCode.network:
      return 'Không kết nối được máy chủ.';
    case ApiErrorCode.unknown:
      return 'Đã xảy ra lỗi. Vui lòng thử lại.';
  }
}