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

  /// Ghi giao dịch lên server. Trả bản ghi đã lưu để UI hiện ngay.
  Future<TransactionItem> addTransaction(NewTransaction input);

  /// Sửa giao dịch (rev+1). Trả bản ghi đã lưu.
  Future<TransactionItem> updateTransaction(String id, NewTransaction input, {required int rev});

  /// Xóa mềm giao dịch.
  Future<void> deleteTransaction(String id, {required int rev});

  /// Chi tiết một giao dịch, kèm ảnh hóa đơn. Danh sách không kèm ảnh nên
  /// mở chi tiết mới tải.
  Future<TransactionItem> fetchTransaction(String id);

  List<CategoryItem> get categories;

  Future<List<BudgetItem>> getBudgets();

  Future<StatsData> getStats({required String range});
}
