import 'models.dart';

int dailyLimit({
  required int budget,
  required int spent,
  required int daysLeft,
}) {
  if (budget <= 0) return 0;
  final remaining = budget - spent;
  if (remaining <= 0 || daysLeft <= 0) return remaining;
  return remaining ~/ daysLeft;
}

double spentPercent({
  required int spent,
  required int limit,
}) {
  if (limit <= 0) return 0;
  return (spent / limit * 100).clamp(0, 100).toDouble();
}

int remainingAmount({
  required int budget,
  required int spent,
}) =>
    budget - spent;

int totalByType(List<TransactionItem> items, TransactionType type) {
  return items
      .where((item) => item.type == type)
      .fold(0, (sum, item) => sum + item.amount);
}

/// Tổng hợp số liệu tháng từ danh sách giao dịch.
///
/// Mọi con số hiển thị trên giao diện đều đi qua đây để tránh việc UI
/// tự tính toán lệch với công thức chuẩn.
MonthSummary buildMonthSummary({
  required List<TransactionItem> transactions,
  required int budgetAmount,
  required int daysLeft,
}) {
  final income = totalByType(transactions, TransactionType.income);
  final expense = totalByType(transactions, TransactionType.expense);
  return MonthSummary(
    income: income,
    expense: expense,
    balance: remainingAmount(budget: income, spent: expense),
    dailyLimit: dailyLimit(
      budget: budgetAmount,
      spent: expense,
      daysLeft: daysLeft,
    ),
    budgetAmount: budgetAmount,
    daysLeft: daysLeft,
    spent: expense,
  );
}
