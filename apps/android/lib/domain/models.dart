enum TransactionType { expense, income, transfer }

enum SyncStatus { synced, syncing, offline }

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    this.type = 'expense',
  });

  final String id;
  final String name;

  /// 'expense' | 'income' — lưới danh mục lọc theo loại đang ghi.
  final String type;
}

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.wallet,
    required this.note,
    required this.dayLabel,
    required this.rev,
    this.occurredAt,
    this.paymentMethod,
    this.incomeSource,
    this.receiptMime,
    this.receiptBase64,
    this.hasReceiptFlag = false,
    this.pending = false,
  });

  final String id;
  final int amount;
  final TransactionType type;
  final CategoryItem category;
  final String wallet;
  final String note;
  final String dayLabel;
  final int rev;
  final DateTime? occurredAt;
  final String? paymentMethod;
  final String? incomeSource;
  final String? receiptMime;
  final String? receiptBase64;
  /// Danh sách chỉ biết "có ảnh hay không"; bytes ảnh chỉ có khi tải chi tiết.
  final bool hasReceiptFlag;
  final bool pending;

  bool get hasReceipt =>
      hasReceiptFlag ||
      (receiptBase64 != null &&
          receiptBase64!.isNotEmpty &&
          receiptMime != null &&
          receiptMime!.isNotEmpty);
}

class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.name,
    required this.limit,
    required this.spent,
    required this.remaining,
    required this.percent,
    required this.periodLabel,
  });

  final String id;
  final String name;
  final int limit;
  final int spent;
  final int remaining;
  final double percent;
  final String periodLabel;
}

class MonthSummary {
  const MonthSummary({
    required this.income,
    required this.expense,
    required this.balance,
    required this.dailyLimit,
    required this.budgetAmount,
    required this.daysLeft,
    required this.spent,
  });

  final int income;
  final int expense;
  final int balance;
  final int dailyLimit;
  final int budgetAmount;
  final int daysLeft;
  final int spent;
}

class DashboardData {
  const DashboardData({
    required this.summary,
    required this.budgets,
    required this.recent,
    required this.syncStatus,
    this.isEmpty = false,
  });

  final MonthSummary summary;
  final List<BudgetItem> budgets;
  final List<TransactionItem> recent;
  final SyncStatus syncStatus;
  final bool isEmpty;
}

class CategoryTotal {
  const CategoryTotal({
    required this.name,
    required this.amount,
    required this.percent,
  });

  final String name;
  final int amount;
  final double percent;
}

class DayTotal {
  const DayTotal({required this.label, required this.amount});

  final String label;
  final int amount;
}

class StatsData {
  const StatsData({
    required this.categories,
    required this.daily,
    required this.totalExpense,
    this.comparisonPercent,
    this.previousExpense,
    this.isEmpty = false,
  });

  final List<CategoryTotal> categories;
  final List<DayTotal> daily;
  final int totalExpense;

  /// Mức tăng/giảm so với kỳ trước, tính theo %. `null` khi không có mốc
  /// để so sánh (chưa chi gì ở kỳ trước) — khác hẳn với 0% (không đổi).
  final int? comparisonPercent;

  /// Chi tiêu kỳ trước, dùng cho phần chú thích dưới thẻ so sánh.
  final int? previousExpense;

  final bool isEmpty;
}
