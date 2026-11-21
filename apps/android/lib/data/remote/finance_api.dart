import 'dart:typed_data';

import 'package:android/data/remote/api_client.dart';
import 'package:android/data/remote/dto.dart';

/// Các lời gọi API Student Finance, mỗi hàm ứng với một endpoint trong
/// `docs/system-design/02-api-contract.md`.
class FinanceApi {
  FinanceApi(this._client);

  final ApiClient _client;

  Future<MeDto> me() async {
    final json = await _client.get<Map<String, dynamic>>('/v1/me');
    return MeDto.fromJson(json);
  }

  /// Cập nhật hồ sơ. Chỉ gửi trường thực sự đổi — `null` nghĩa là "giữ nguyên".
  Future<MeDto> updateMe({
    String? displayName,
    String? username,
    String? currency,
    String? timezone,
  }) async {
    final json = await _client.patch<Map<String, dynamic>>(
      '/v1/me',
      data: {
        'display_name': ?displayName,
        'username': ?username,
        'currency': ?currency,
        'timezone': ?timezone,
      },
    );
    return MeDto.fromJson(json);
  }

  /// Ảnh đại diện đã cắt sẵn, gửi base64. Trả hồ sơ mới (`has_avatar = true`).
  Future<MeDto> uploadAvatar({
    required String base64Data,
    String mime = 'image/jpeg',
  }) async {
    final json = await _client.put<Map<String, dynamic>>(
      '/v1/me/avatar',
      data: {'mime': mime, 'data': base64Data},
    );
    return MeDto.fromJson(json);
  }

  /// Bytes ảnh đại diện, `null` nếu chưa đặt ảnh (server trả 404).
  Future<Uint8List?> avatarBytes() async {
    return _client.getBytes('/v1/me/avatar');
  }

  Future<MeDto> deleteAvatar() async {
    final json = await _client.delete<Map<String, dynamic>>('/v1/me/avatar');
    return MeDto.fromJson(json);
  }

  /// `includeDeleted` dùng khi đồng bộ offline cần biết ví nào đã bị xoá.
  Future<List<WalletDto>> wallets({bool includeDeleted = false}) async {
    final path = includeDeleted
        ? '/v1/wallets?include_deleted=true'
        : '/v1/wallets';
    final json = await _client.get<List<dynamic>>(path);
    return json
        .map((item) => WalletDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Số dư gộp theo ví và theo loại, server tính sẵn.
  Future<WalletBalanceSummaryDto> walletSummary() async {
    final json = await _client.get<Map<String, dynamic>>('/v1/wallets/summary');
    return WalletBalanceSummaryDto.fromJson(json);
  }

  /// Xoá mềm ví. `rev` nên bằng `rev` hiện tại + 1 để phát hiện xung đột.
  Future<WalletDto> deleteWallet(String id, {int? rev}) async {
    final json = await _client.delete<Map<String, dynamic>>(
      '/v1/wallets/$id${rev == null ? '' : '?rev=$rev'}',
    );
    return WalletDto.fromJson(json);
  }

  /// Tạo ví. `id` do client sinh để gọi lại cùng id là idempotent (đồng bộ
  /// offline gửi lại được mà không sinh ví trùng).
  Future<WalletDto> createWallet(Map<String, dynamic> data) async {
    final json = await _client.post<Map<String, dynamic>>(
      '/v1/wallets',
      data: data,
    );
    return WalletDto.fromJson(json);
  }

  /// Sửa ví. `data` phải có `rev` = rev hiện tại + 1.
  Future<WalletDto> updateWallet(String id, Map<String, dynamic> data) async {
    final json = await _client.patch<Map<String, dynamic>>(
      '/v1/wallets/$id',
      data: data,
    );
    return WalletDto.fromJson(json);
  }

  /// Hộp thư thông báo, mới nhất trước.
  Future<NotificationListDto> notifications({int limit = 30}) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/v1/notifications?limit=$limit',
    );
    return NotificationListDto.fromJson(json);
  }

  /// Chỉ con số, nhẹ hơn tải cả hộp thư khi chỉ cần badge.
  Future<int> unreadNotificationCount() async {
    final json = await _client.get<Map<String, dynamic>>(
      '/v1/notifications/unread-count',
    );
    return (json['unread_count'] as num?)?.toInt() ?? 0;
  }

  /// Đánh dấu một tin đã đọc.
  Future<NotificationDto> markNotificationRead(String id) async {
    final json = await _client.post<Map<String, dynamic>>(
      '/v1/notifications/$id/read',
    );
    return NotificationDto.fromJson(json);
  }

  /// Đánh dấu tất cả đã đọc. Trả số dòng vừa đổi.
  Future<int> markAllNotificationsRead() async {
    final json = await _client.post<Map<String, dynamic>>(
      '/v1/notifications/read-all',
    );
    return (json['updated'] as num?)?.toInt() ?? 0;
  }

  Future<List<CategoryDto>> categories({bool includeDeleted = false}) async {
    final path = includeDeleted
        ? '/v1/categories?include_deleted=true'
        : '/v1/categories';
    final json = await _client.get<List<dynamic>>(path);
    return json
        .map((item) => CategoryDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Xoá mềm danh mục của mình. Danh mục hệ thống bị server chặn (403).
  Future<CategoryDto> deleteCategory(String id, {int? rev}) async {
    final json = await _client.delete<Map<String, dynamic>>(
      '/v1/categories/$id${rev == null ? '' : '?rev=$rev'}',
    );
    return CategoryDto.fromJson(json);
  }

  Future<List<TransactionDto>> transactions({
    int limit = 50,
    DateTime? before,
  }) async {
    final json = await _client.get<List<dynamic>>(
      '/v1/transactions',
      query: {
        'limit': limit,
        if (before != null) 'before': before.toUtc().toIso8601String(),
      },
    );
    return json
        .map((item) => TransactionDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TransactionDto> createTransaction(Map<String, dynamic> body) async {
    final json = await _client.post<Map<String, dynamic>>(
      '/v1/transactions',
      data: body,
    );
    return TransactionDto.fromJson(json);
  }

  /// Chi tiết một giao dịch — bản duy nhất có `receipt_base64`.
  Future<TransactionDto> transaction(String id) async {
    final json = await _client.get<Map<String, dynamic>>('/v1/transactions/$id');
    return TransactionDto.fromJson(json);
  }

  Future<TransactionDto> updateTransaction(
    String id,
    Map<String, dynamic> body,
  ) async {
    final json = await _client.patch<Map<String, dynamic>>(
      '/v1/transactions/$id',
      data: body,
    );
    return TransactionDto.fromJson(json);
  }

  /// Xóa mềm: server yêu cầu PATCH deleted_at + rev+1.
  Future<TransactionDto> deleteTransaction(String id, {required int rev}) async {
    final json = await _client.patch<Map<String, dynamic>>(
      '/v1/transactions/$id',
      data: {
        'rev': rev + 1,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return TransactionDto.fromJson(json);
  }

  Future<List<BudgetDto>> budgets({bool active = false}) async {
    final json = await _client.get<List<dynamic>>(
      '/v1/budgets',
      query: active ? {'active': 'true'} : null,
    );
    return json
        .map((item) => BudgetDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Tạo ngân sách. Mỗi cặp (category, period) chỉ có một ngân sách đang
  /// áp dụng: đã có thì server trả `RULE_VIOLATION` và app phải PATCH.
  Future<BudgetDto> createBudget(Map<String, dynamic> data) async {
    final json = await _client.post<Map<String, dynamic>>(
      '/v1/budgets',
      data: data,
    );
    return BudgetDto.fromJson(json);
  }

  /// Sửa hạn mức. `data` phải có `rev` = rev hiện tại + 1.
  Future<BudgetDto> updateBudget(String id, Map<String, dynamic> data) async {
    final json = await _client.patch<Map<String, dynamic>>(
      '/v1/budgets/$id',
      data: data,
    );
    return BudgetDto.fromJson(json);
  }

  Future<List<BudgetProgressDto>> budgetProgress() async {
    final json = await _client.get<Map<String, dynamic>>('/v1/budgets/progress');
    final items = json['items'] as List<dynamic>;
    return items
        .map((item) => BudgetProgressDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Mục tiêu tiết kiệm, chưa hoàn thành trước.
  Future<List<GoalDto>> goals() async {
    final json = await _client.get<Map<String, dynamic>>('/v1/goals');
    final items = json['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => GoalDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Tạo mục tiêu. `id` do client sinh để gọi lại cùng id là idempotent.
  Future<GoalDto> createGoal(Map<String, dynamic> data) async {
    final json = await _client.post<Map<String, dynamic>>(
      '/v1/goals',
      data: data,
    );
    return GoalDto.fromJson(json);
  }

  /// Cập nhật mục tiêu. `data` phải có `rev` = rev hiện tại + 1.
  Future<GoalDto> updateGoal(String id, Map<String, dynamic> data) async {
    final json = await _client.patch<Map<String, dynamic>>(
      '/v1/goals/$id',
      data: data,
    );
    return GoalDto.fromJson(json);
  }

  Future<void> deleteGoal(String id) async {
    await _client.delete<dynamic>('/v1/goals/$id');
  }

  Future<MonthSummaryDto> monthSummary({
    required int year,
    required int month,
  }) async {
    final json = await _client.get<Map<String, dynamic>>(
      '/v1/reports/month-summary',
      query: {'year': year, 'month': month},
    );
    return MonthSummaryDto.fromJson(json);
  }
}