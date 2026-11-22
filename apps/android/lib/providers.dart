import 'dart:convert';
import 'dart:typed_data';

import 'package:android/data/api_finance_repository.dart';
import 'package:android/data/finance_repository.dart';
import 'package:android/data/remote/dto.dart';
import 'package:android/domain/models.dart';
import 'package:android/core/session/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository dữ liệu. Chỉ có một đường: API thật.
///
/// Chưa đăng nhập thì [AuthGate] đã chặn trước khi màn hình nào đọc provider
/// này, nên không cần nhánh dự phòng. Trước đây provider trả bản giả khi chưa
/// đăng nhập — đó là đường vòng khiến người dùng thấy số liệu không phải của
/// mình.
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return ApiFinanceRepository(ref.watch(financeApiProvider));
});

class RangeNotifier extends Notifier<String> {
  @override
  String build() => 'current';

  void select(String range) => state = range;
}

final statsRangeProvider = NotifierProvider<RangeNotifier, String>(
  RangeNotifier.new,
);

/// Danh mục cho form nhập liệu. Với repository mạng, phải nạp từ API trước.
final categoriesProvider = FutureProvider<List<CategoryItem>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  if (repo is ApiFinanceRepository) await repo.warmUp();
  return repo.categories;
});

/// Tên ví cho form nhập liệu, lấy từ danh sách ví thật.
final walletNamesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  if (repo is ApiFinanceRepository) {
    await repo.warmUp();
    return repo.wallets;
  }
  return const [];
});

final dashboardProvider = FutureProvider<DashboardData>((ref) {
  return ref.watch(financeRepositoryProvider).getDashboard();
});

final transactionsProvider = FutureProvider<List<TransactionItem>>((ref) {
  return ref.watch(financeRepositoryProvider).getTransactions();
});

/// Giao dịch của một tháng cụ thể, cho màn lịch.
///
/// Khoá là `(năm, tháng)` nên mỗi tháng được cache riêng: bấm qua lại giữa
/// hai tháng không tải lại, mà cũng không phải tải cả năm một lần.
///
/// Cố ý **không** `autoDispose`: đổi sang chế độ Danh sách rồi quay lại Lịch
/// là widget lịch bị dựng lại, `autoDispose` sẽ xoá cache và tải lại tháng
/// vừa xem — người dùng thấy vòng xoay ở đúng chỗ vừa rời.
final monthTransactionsProvider =
    FutureProvider.family<List<TransactionItem>, ({int year, int month})>((ref, key) {
  return ref
      .watch(financeRepositoryProvider)
      .getTransactionsInMonth(key.year, key.month);
});

/// Ảnh của một giao dịch. Khoá theo id giao dịch để mở lại chi tiết không
/// phải tải lại; `invalidate` sau khi thêm/xoá ảnh.
final transactionPhotosProvider =
    FutureProvider.family<List<PhotoNote>, String>((ref, transactionId) {
  return ref
      .watch(financeRepositoryProvider)
      .getPhotoNotes(transactionId: transactionId);
});

/// Toàn bộ sổ ảnh, mới nhất trước.
final allPhotosProvider = FutureProvider<List<PhotoNote>>((ref) {
  return ref.watch(financeRepositoryProvider).getPhotoNotes();
});

/// Bytes một ảnh để hiển thị. Danh sách không mang ảnh nên phải tải riêng.
final photoBytesProvider =
    FutureProvider.family<Uint8List?, String>((ref, photoId) async {
  final note = await ref.watch(financeRepositoryProvider).fetchPhotoNote(photoId);
  final raw = note.photoBase64;
  if (raw == null || raw.isEmpty) return null;
  return base64Decode(raw);
});

final budgetsProvider = FutureProvider<List<BudgetItem>>((ref) {
  return ref.watch(financeRepositoryProvider).getBudgets();
});

final statsProvider = FutureProvider<StatsData>((ref) {
  final range = ref.watch(statsRangeProvider);
  return ref.watch(financeRepositoryProvider).getStats(range: range);
});

/// Danh sách ví đầy đủ cho màn "Ví của tôi".
///
/// Không dùng chung cache của [financeRepositoryProvider] vì màn này cần
/// `rev` để sửa/xoá, còn form nhập liệu chỉ cần tên.
final walletsProvider = FutureProvider<List<WalletDto>>((ref) {
  return ref.watch(financeApiProvider).wallets();
});

/// Tiến độ ngân sách theo từng hũ cho tab Ngân sách. Server đã tính sẵn
/// `spent`, `remaining`, `used_pct` và `days_left` nên UI không tự suy ra.
final budgetProgressProvider = FutureProvider<List<BudgetProgressDto>>((ref) {
  return ref.watch(financeApiProvider).budgetProgress();
});

/// Ngân sách đang áp dụng, kèm `rev` để sửa. Khác [budgetProgressProvider]:
/// provider kia chỉ có số đã tiêu, không có `rev` nên không PATCH được.
final activeBudgetsProvider = FutureProvider<List<BudgetDto>>((ref) {
  return ref.watch(financeApiProvider).budgets(active: true);
});

/// Chia hủ của tháng hiện tại: hạn mức từng hũ tính từ ngân sách tháng.
///
/// Tách khỏi [budgetProgressProvider] vì hũ là cách *chia* ngân sách, không
/// phải hạn mức của danh mục — hai bảng, hai cách tính.
final budgetJarsProvider = FutureProvider<BudgetJarSummaryDto>((ref) {
  return ref.watch(financeApiProvider).budgetJars();
});

/// Mục tiêu tiết kiệm cho thẻ thử thách ở trang chủ.
final goalsProvider = FutureProvider<List<GoalDto>>((ref) {
  return ref.watch(financeApiProvider).goals();
});

/// Hộp thư thông báo, mới nhất trước.
final notificationsProvider = FutureProvider<NotificationListDto>((ref) {
  return ref.watch(financeApiProvider).notifications();
});

/// Số tin chưa đọc cho badge chuông. Tách khỏi [notificationsProvider] để
/// trang chủ không phải tải cả nội dung hộp thư chỉ để vẽ một con số.
final unreadCountProvider = FutureProvider<int>((ref) {
  return ref.watch(financeApiProvider).unreadNotificationCount();
});
