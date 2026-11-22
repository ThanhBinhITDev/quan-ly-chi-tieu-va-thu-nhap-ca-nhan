import 'dart:typed_data';

import 'package:android/domain/models.dart';
import 'package:android/domain/transaction_input.dart';

/// Hợp đồng dữ liệu của tầng UI. Chỉ có một bản cài đặt: [ApiFinanceRepository].
///
/// Trước đây interface này có thêm tham số `DemoScenario` để một bản giả đổi
/// kịch bản (mẫu/trống/lỗi/offline) khi thử giao diện. Đã bỏ: kịch bản giả
/// khiến app có hai nguồn sự thật, và người dùng thật có thể lạc vào dữ liệu
/// mẫu mà không biết. Trạng thái trống/lỗi/offline giờ do dữ liệu thật quyết
/// định, không do công tắc trên giao diện.
abstract class FinanceRepository {
  Future<DashboardData> getDashboard();

  Future<List<TransactionItem>> getTransactions();

  /// Giao dịch của một tháng, tải đủ mọi trang.
  ///
  /// [getTransactions] chỉ lấy 100 khoản gần nhất — đủ cho danh sách, nhưng
  /// lịch mà lùi về tháng trước sẽ trống dù tháng đó có chi tiêu. Màn lịch
  /// phải hỏi theo tháng thay vì lọc mảng đã tải.
  Future<List<TransactionItem>> getTransactionsInMonth(int year, int month);

  /// Ghi giao dịch lên server. Trả bản ghi đã lưu để UI hiện ngay.
  Future<TransactionItem> addTransaction(NewTransaction input);

  /// Sửa giao dịch (rev+1). Trả bản ghi đã lưu.
  Future<TransactionItem> updateTransaction(String id, NewTransaction input, {required int rev});

  /// Xóa mềm giao dịch.
  Future<void> deleteTransaction(String id, {required int rev});

  /// Chi tiết một giao dịch, kèm ảnh hóa đơn. Danh sách không kèm ảnh nên
  /// mở chi tiết mới tải.
  Future<TransactionItem> fetchTransaction(String id);

  // ── Sổ ảnh ────────────────────────────────────────────────────────────

  /// Ảnh của các khoản chi/thu, mới nhất trước.
  ///
  /// Ảnh luôn thuộc một giao dịch, nên không có "ảnh rời". Chiều ngược lại
  /// mới tuỳ chọn: giao dịch không cần ảnh.
  Future<List<PhotoNote>> getPhotoNotes({String? transactionId});

  /// Chi tiết một ảnh, kèm bytes để hiển thị.
  Future<PhotoNote> fetchPhotoNote(String id);

  /// Gắn một ảnh mới vào giao dịch. Trả bản đã lưu.
  Future<PhotoNote> addPhotoNote({
    required String transactionId,
    required Uint8List bytes,
    required String mime,
    String? caption,
    DateTime? takenAt,
  });

  /// Sửa ghi chú của ảnh (rev+1).
  Future<PhotoNote> updatePhotoNoteCaption(
    String id,
    String caption, {
    required int rev,
  });

  Future<void> deletePhotoNote(String id);

  List<CategoryItem> get categories;

  Future<List<BudgetItem>> getBudgets();

  Future<StatsData> getStats({required String range});
}
