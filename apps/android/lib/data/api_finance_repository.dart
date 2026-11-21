import 'package:android/core/error/app_exception.dart';
import 'package:android/core/utils/uuid.dart';
import 'package:android/data/remote/dto.dart';
import 'package:android/data/finance_repository.dart';
import 'package:android/data/remote/finance_api.dart';
import 'package:android/domain/models.dart';
import 'package:android/domain/transaction_input.dart';

/// Nối dữ liệu API vào model mà tầng UI đang dùng.
///
/// UI hiện tại được viết cho [FinanceRepository] với model nội bộ
/// (`TransactionItem`, `BudgetItem`...). Lớp này làm nhiệm vụ chuyển đổi, để
/// không phải viết lại toàn bộ màn hình khi nối mạng.
class ApiFinanceRepository implements FinanceRepository {
  ApiFinanceRepository(this._api);

  final FinanceApi _api;

  List<CategoryDto> _categoryCache = const [];
  List<WalletDto> _walletCache = const [];

  @override
  List<CategoryItem> get categories => _categoryCache
      .map((c) => CategoryItem(id: c.id, name: c.name, type: c.type))
      .toList();

  /// Tên các ví hiện có (dùng cho ô chọn ví trong form).
  List<String> get wallets => _walletCache.map((w) => w.name).toList();

  /// Danh sách ví đầy đủ cho màn "Ví của tôi".
  Future<List<WalletDto>> walletsDetailed() async {
    final rows = await _api.wallets();
    _walletCache = rows;
    return rows;
  }

  /// Nạp danh mục và ví một lần để các màn hình dùng lại.
  Future<void> warmUp() async {
    final results = await Future.wait([
      _api.categories(),
      _api.wallets(),
    ]);
    _categoryCache = results[0] as List<CategoryDto>;
    _walletCache = results[1] as List<WalletDto>;
  }

  /// Bảo đảm cache danh mục/ví đã có trước khi dịch id sang tên.
  ///
  /// Trước đây chỉ form nhập liệu gọi `warmUp()`, nên mở tab Giao dịch trước
  /// sẽ thấy mọi khoản chi là "Khác": API trả `category_id` đúng, nhưng cache
  /// rỗng nên tra không ra tên. Nạp ở đây là điều kiện để hiển thị đúng.
  Future<void> _ensureCaches() async {
    if (_categoryCache.isNotEmpty && _walletCache.isNotEmpty) return;
    try {
      await warmUp();
    } on AppException {
      // Tên danh mục chỉ để hiển thị. Nạp lỗi thì vẫn phải hiện được giao
      // dịch với nhãn "Khác", không để cả trang trắng vì một request phụ.
    }
  }

  /// Tạo ví mới với số dư ban đầu. Đây là đường duy nhất để "khai" số tiền
  /// đang có, vì số dư hiện tại luôn tính từ mốc này cộng giao dịch.
  Future<WalletDto> createWallet({
    required String name,
    required String type,
    required int initialBalance,
  }) async {
    final created = await _api.createWallet({
      'id': generateUuidV4(),
      'name': name,
      'type': type,
      'initial_balance': initialBalance,
    });
    _walletCache = [..._walletCache, created];
    return created;
  }

  /// Sửa tên hoặc số dư ban đầu. `rev` phải là rev hiện tại + 1, sai thì
  /// server trả SYNC_CONFLICT — dùng để phát hiện hai máy sửa cùng lúc.
  Future<WalletDto> updateWallet({
    required String id,
    required int rev,
    String? name,
    int? initialBalance,
  }) async {
    final updated = await _api.updateWallet(id, {
      'rev': rev + 1,
      'name': ?name,
      'initial_balance': ?initialBalance,
    });
    _walletCache = _walletCache
        .map((w) => w.id == updated.id ? updated : w)
        .toList();
    return updated;
  }

  Future<void> deleteWallet(String id, {int? rev}) async {
    await _api.deleteWallet(id, rev: rev);
    _walletCache = _walletCache.where((w) => w.id != id).toList();
  }

  @override
  Future<DashboardData> getDashboard() async {
    final month = _currentMonth();
    // "Giao dịch gần đây" cũng hiện tên danh mục, nên phải có cache trước khi
    // map; không có thì mọi dòng thành "Khác".
    await _ensureCaches();
    try {
      final results = await Future.wait([
        _api.monthSummary(year: month.$1, month: month.$2),
        _api.budgetProgress(),
        _api.transactions(limit: 5),
        _api.walletSummary(),
      ]);
      final summary = results[0] as MonthSummaryDto;
      final budgets = results[1] as List<BudgetProgressDto>;
      final recent = results[2] as List<TransactionDto>;
      final walletSummary = results[3] as WalletBalanceSummaryDto;

      return DashboardData(
        summary: MonthSummary(
          income: summary.income,
          expense: summary.expense,
          // "Số dư hiện tại" là tiền thật trong các ví (server tính), không
          // phải remaining của ngân sách tháng.
          balance: walletSummary.totalBalance,
          dailyLimit: summary.dailyLimit,
          budgetAmount: summary.budgetTotal,
          daysLeft: summary.daysLeft,
          spent: summary.expense,
        ),
        budgets: budgets.map(_toBudgetItem).toList(),
        recent: recent.isEmpty
            ? const []
            : recent.map(_toTransactionItem).toList(),
        syncStatus: SyncStatus.synced,
        isEmpty: summary.income == 0 &&
            summary.expense == 0 &&
            budgets.isEmpty,
      );
    } on AppException catch (error) {
      if (error.code == ApiErrorCode.network) {
        // Mất mạng không phải lỗi hiển thị: UI hiện trạng thái offline.
        return DashboardData(
          summary: const MonthSummary(
            income: 0,
            expense: 0,
            balance: 0,
            dailyLimit: 0,
            budgetAmount: 0,
            daysLeft: 0,
            spent: 0,
          ),
          budgets: const [],
          recent: const [],
          syncStatus: SyncStatus.offline,
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<TransactionItem>> getTransactions() async {
    await _ensureCaches();
    final rows = await _api.transactions(limit: 100);
    return rows.map(_toTransactionItem).toList();
  }

  /// Body cho `POST /v1/transactions`. Chỉ gồm trường `CreateTransactionDto`
  /// khai báo — server bật `forbidNonWhitelisted` nên gửi thừa là 400.
  Map<String, dynamic> _createBody(NewTransaction input, String id) {
    return {
      'id': id,
      ..._editableFields(input, isUpdate: false),
    };
  }

  /// Body cho `PATCH /v1/transactions/:id`. `UpdateTransactionDto` không có
  /// `id`; các trường còn lại dùng chung với create.
  Map<String, dynamic> _updateBody(NewTransaction input, {required int rev}) {
    return {
      ..._editableFields(input, isUpdate: true),
      'rev': rev + 1,
    };
  }

  Map<String, dynamic> _editableFields(
    NewTransaction input, {
    required bool isUpdate,
  }) {
    final wallet = _walletCache.firstWhere(
      (w) => w.name == input.wallet,
      orElse: () => _walletCache.first,
    );
    final category = _categoryCache.firstWhere(
      (c) => c.name == input.category.name || c.id == input.category.id,
      orElse: () => _categoryCache.isEmpty
          ? const CategoryDto(id: '', name: '', type: 'expense', isSystem: false, rev: 1)
          : _categoryCache.first,
    );
    return {
      'wallet_id': wallet.id,
      if (category.id.isNotEmpty) 'category_id': category.id,
      'type': _apiTypeValue(input.type),
      'amount': input.amount,
      'note': input.note,
      'occurred_at': input.occurredAt.toUtc().toIso8601String(),
      'payment_method': ?input.paymentMethod,
      // Gửi `null` rõ ràng = xóa trắng; bỏ hẳn key = giữ nguyên.
      'income_source': input.incomeSource?.trim().isNotEmpty == true
          ? input.incomeSource!.trim()
          : null,
      'receipt_base64': ?input.receiptBase64,
      'receipt_mime': ?input.receiptMime,
      // `remove_receipt` chỉ tồn tại ở DTO sửa; gửi kèm lúc tạo là 400.
      if (isUpdate && input.removeReceipt) 'remove_receipt': true,
    };
  }

  @override
  Future<TransactionItem> addTransaction(NewTransaction input) async {
    if (_walletCache.isEmpty) await warmUp();
    final created = await _api.createTransaction(
      _createBody(input, generateUuidV4()),
    );
    return _toTransactionItem(created);
  }

  @override
  Future<TransactionItem> updateTransaction(
    String id,
    NewTransaction input, {
    required int rev,
  }) async {
    if (_walletCache.isEmpty || _categoryCache.isEmpty) await warmUp();
    final updated = await _api.updateTransaction(
      id,
      _updateBody(input, rev: rev),
    );
    return _toTransactionItem(updated);
  }

  @override
  Future<TransactionItem> fetchTransaction(String id) async {
    await _ensureCaches();
    return _toTransactionItem(await _api.transaction(id));
  }

  @override
  Future<List<TransactionItem>> getTransactionsInMonth(
    int year,
    int month,
  ) async {
    await _ensureCaches();
    final monthStart = DateTime(year, month);
    // `before` là mốc loại trừ: lấy mọi bản ghi có `occurred_at` nhỏ hơn mốc.
    // Đầu tháng sau là mốc đúng để gồm trọn tháng này.
    final monthEnd = DateTime(year, month + 1);
    // Khoá theo id: nhiều giao dịch cùng một mốc `occurred_at` làm cursor
    // không tiến, trang sau trả lại đúng các bản ghi vừa nhận. Không chặn
    // thì tiền của ngày đó bị cộng hai lần trên lịch.
    final collected = <String, TransactionDto>{};
    var cursor = monthEnd;

    // Trần 200 là giới hạn server cho `limit`; một tháng nhiều khoản hơn thì
    // phải đi tiếp bằng cursor, nếu không lịch sẽ thiếu tiền mà không báo gì.
    for (var page = 0; page < 20; page++) {
      final rows = await _api.transactions(limit: 200, before: cursor);
      if (rows.isEmpty) break;
      var reachedOlderMonth = false;
      for (final row in rows) {
        final at = row.occurredAt.toLocal();
        // Chặn cả hai đầu: server đã lọc theo `before` nên phía trên hiếm khi
        // lọt, nhưng bản ghi đúng ngày cuối tháng rơi vào tháng sau nếu chỉ
        // so một phía.
        if (!at.isBefore(monthStart) && at.isBefore(monthEnd)) {
          collected[row.id] = row;
        } else if (at.isBefore(monthStart)) {
          reachedOlderMonth = true;
        }
      }
      if (reachedOlderMonth) break;
      // Cursor mới là bản ghi cũ nhất vừa nhận, không phải `now`: server sắp
      // xếp giảm dần theo `occurred_at`.
      final oldest = rows.last.occurredAt;
      if (!oldest.isBefore(cursor)) break;
      cursor = oldest;
    }
    return collected.values.map(_toTransactionItem).toList();
  }

  @override
  Future<void> deleteTransaction(String id, {required int rev}) async {
    await _api.deleteTransaction(id, rev: rev);
  }

  @override
  Future<List<BudgetItem>> getBudgets() async {
    final rows = await _api.budgetProgress();
    return rows.map(_toBudgetItem).toList();
  }

  @override
  Future<StatsData> getStats({required String range}) async {
    final now = DateTime.now();
    // Chip "Tháng trước" phải thật sự đổi kỳ dữ liệu, không chỉ đổi nhãn.
    final anchor = range == 'previous'
        ? DateTime(now.year, now.month - 1)
        : now;
    final summary = await _api.monthSummary(
      year: anchor.year,
      month: anchor.month,
    );

    return StatsData(
      categories: summary.byCategory
          .map(
            (c) => CategoryTotal(
              name: c.name,
              amount: c.total,
              percent: c.pct,
            ),
          )
          .toList(),
      daily: summary.byDay
          .map((d) => DayTotal(label: _dayLabel(d.date), amount: d.total))
          .toList(),
      totalExpense: summary.expense,
      comparisonPercent: summary.deltaPct,
      previousExpense: summary.previousExpense,
      isEmpty: summary.expense == 0,
    );
  }

  BudgetItem _toBudgetItem(BudgetProgressDto dto) => BudgetItem(
        id: dto.budgetId,
        name: dto.name,
        limit: dto.amount,
        spent: dto.spent,
        remaining: dto.remaining,
        percent: dto.usedPct,
        periodLabel: dto.daysLeft > 0 ? 'Còn ${dto.daysLeft} ngày' : 'Hết kỳ',
      );

  TransactionItem _toTransactionItem(TransactionDto dto) {
    final category = _categoryCache
        .where((c) => c.id == dto.categoryId)
        .map((c) => CategoryItem(id: c.id, name: c.name))
        .firstOrNull;
    final wallet = _walletCache
        .where((w) => w.id == dto.walletId)
        .map((w) => w.name)
        .firstOrNull;

    return TransactionItem(
      id: dto.id,
      amount: dto.amount,
      type: _toDomainType(dto.type),
      category: category ?? const CategoryItem(id: '', name: 'Khác'),
      wallet: wallet ?? '',
      note: dto.note ?? '',
      dayLabel: _dayLabel(dto.occurredOn ?? dto.occurredAt.toIso8601String()),
      rev: dto.rev,
      occurredAt: dto.occurredAt.toLocal(),
      paymentMethod: dto.paymentMethod,
      incomeSource: dto.incomeSource,
      receiptMime: dto.receiptMime,
      receiptBase64: dto.receiptBase64,
      hasReceiptFlag: dto.hasReceiptFlag,
    );
  }

  (int, int) _currentMonth() {
    final now = DateTime.now();
    return (now.year, now.month);
  }

  String _apiTypeValue(TransactionType type) => switch (type) {
        TransactionType.income => 'income',
        TransactionType.transfer => 'transfer',
        TransactionType.expense => 'expense',
      };

  TransactionType _toDomainType(ApiTransactionType type) => switch (type) {
        ApiTransactionType.income => TransactionType.income,
        ApiTransactionType.transfer => TransactionType.transfer,
        ApiTransactionType.expense => TransactionType.expense,
      };

  String _dayLabel(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    return '${day.day.toString().padLeft(2, '0')}/'
        '${day.month.toString().padLeft(2, '0')}';
  }
}
