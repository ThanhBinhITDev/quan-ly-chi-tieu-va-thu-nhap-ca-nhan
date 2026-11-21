/// Model bám sát JSON API trả về (snake_case), không đoán thêm trường.
library;

/// Loại giao dịch theo API. Tách khỏi enum của tầng UI để đổi API không phá UI.
enum ApiTransactionType {
  expense,
  income,
  transfer;

  static ApiTransactionType parse(String raw) => switch (raw) {
        'income' => ApiTransactionType.income,
        'transfer' => ApiTransactionType.transfer,
        _ => ApiTransactionType.expense,
      };

  String get apiValue => name;
}

class WalletDto {
  const WalletDto({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.rev,
    this.balance,
    this.color,
    this.icon,
    this.isArchived = false,
    this.deletedAt,
  });

  factory WalletDto.fromJson(Map<String, dynamic> json) => WalletDto(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        initialBalance: (json['initial_balance'] as num?)?.toInt() ?? 0,
        // Server luôn tính `balance`; thiếu thì coi như bằng số dư ban đầu.
        balance:
            (json['balance'] as num?)?.toInt() ??
                (json['initial_balance'] as num?)?.toInt() ??
                0,
        rev: (json['rev'] as num?)?.toInt() ?? 1,
        color: json['color'] as String?,
        icon: json['icon'] as String?,
        isArchived: json['is_archived'] as bool? ?? false,
        deletedAt: _parseDate(json['deleted_at']),
      );

  final String id;
  final String name;

  /// 'cash' | 'bank' | 'ewallet' | 'credit' — xem migration.
  final String type;
  final int initialBalance;

  /// Số dư hiện tại do server tính (initial_balance + giao dịch). Chỉ đọc.
  final int? balance;
  final int rev;
  final String? color;
  final String? icon;
  final bool isArchived;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}

/// `null` giữ nguyên null, chuỗi ISO thì parse, kiểu khác thì bỏ qua.
DateTime? _parseDate(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

/// `GET /v1/wallets/summary` — số dư gộp, server tính sẵn.
class WalletBalanceSummaryDto {
  const WalletBalanceSummaryDto({
    required this.wallets,
    required this.totalBalance,
    required this.byType,
    required this.computedAt,
  });

  factory WalletBalanceSummaryDto.fromJson(Map<String, dynamic> json) =>
      WalletBalanceSummaryDto(
        wallets: ((json['wallets'] as List<dynamic>?) ?? const [])
            .map((e) => WalletBalanceDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalBalance: (json['total_balance'] as num?)?.toInt() ?? 0,
        byType: ((json['by_type'] as Map<String, dynamic>?) ?? const {})
            .map((key, value) => MapEntry(key, (value as num).toInt())),
        computedAt: DateTime.parse(json['computed_at'] as String),
      );

  final List<WalletBalanceDto> wallets;
  final int totalBalance;
  final Map<String, int> byType;
  final DateTime computedAt;
}

class WalletBalanceDto {
  const WalletBalanceDto({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.isArchived = false,
  });

  factory WalletBalanceDto.fromJson(Map<String, dynamic> json) =>
      WalletBalanceDto(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        isArchived: json['is_archived'] as bool? ?? false,
      );

  final String id;
  final String name;
  final String type;
  final int balance;
  final bool isArchived;
}

class CategoryDto {
  const CategoryDto({
    required this.id,
    required this.name,
    required this.type,
    required this.isSystem,
    required this.rev,
    this.icon,
    this.color,
    this.parentId,
    this.sortOrder = 0,
    this.deletedAt,
  });

  factory CategoryDto.fromJson(Map<String, dynamic> json) => CategoryDto(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        isSystem: json['is_system'] as bool? ?? false,
        rev: (json['rev'] as num?)?.toInt() ?? 1,
        icon: json['icon'] as String?,
        color: json['color'] as String?,
        parentId: json['parent_id'] as String?,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        deletedAt: _parseDate(json['deleted_at']),
      );

  final String id;
  final String name;
  final String type;
  final bool isSystem;
  final int rev;
  final String? icon;
  final String? color;
  final String? parentId;
  final int sortOrder;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}

class TransactionDto {
  const TransactionDto({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.occurredAt,
    required this.rev,
    this.categoryId,
    this.toWalletId,
    this.note,
    this.occurredOn,
    this.source,
    this.paymentMethod,
    this.incomeSource,
    this.receiptMime,
    this.receiptBase64,
    this.hasReceiptFlag = false,
    this.deletedAt,
  });

  factory TransactionDto.fromJson(Map<String, dynamic> json) => TransactionDto(
        id: json['id'] as String,
        walletId: json['wallet_id'] as String,
        type: ApiTransactionType.parse(json['type'] as String),
        amount: (json['amount'] as num).toInt(),
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        rev: (json['rev'] as num?)?.toInt() ?? 1,
        categoryId: json['category_id'] as String?,
        toWalletId: json['to_wallet_id'] as String?,
        note: json['note'] as String?,
        occurredOn: json['occurred_on'] as String?,
        source: json['source'] as String?,
        paymentMethod: json['payment_method'] as String?,
        incomeSource: json['income_source'] as String?,
        receiptMime: json['receipt_mime'] as String?,
        receiptBase64: json['receipt_base64'] as String?,
        hasReceiptFlag: json['has_receipt'] as bool? ?? false,
        deletedAt: json['deleted_at'] == null
            ? null
            : DateTime.parse(json['deleted_at'] as String),
      );

  final String id;
  final String walletId;
  final ApiTransactionType type;
  final int amount;
  final DateTime occurredAt;
  final int rev;
  final String? categoryId;
  final String? toWalletId;
  final String? note;
  final String? occurredOn;
  final String? source;
  final String? paymentMethod;
  final String? incomeSource;
  final String? receiptMime;
  final String? receiptBase64;
  /// Danh sách chỉ trả cờ này, không trả bytes ảnh.
  final bool hasReceiptFlag;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get hasReceipt =>
      hasReceiptFlag || (receiptBase64 != null && receiptMime != null);
}

class BudgetDto {
  const BudgetDto({
    required this.id,
    required this.amount,
    required this.period,
    required this.startDate,
    required this.rev,
    this.categoryId,
    this.endDate,
  });

  factory BudgetDto.fromJson(Map<String, dynamic> json) => BudgetDto(
        id: json['id'] as String,
        amount: (json['amount'] as num).toInt(),
        period: json['period'] as String,
        startDate: json['start_date'] as String,
        rev: (json['rev'] as num?)?.toInt() ?? 1,
        categoryId: json['category_id'] as String?,
        endDate: json['end_date'] as String?,
      );

  final String id;
  final int amount;
  final String period;
  final String startDate;
  final int rev;

  /// null = ngân sách tổng.
  final String? categoryId;
  final String? endDate;
}

/// Một dòng trong `/v1/budgets/progress`.
class BudgetProgressDto {
  const BudgetProgressDto({
    required this.budgetId,
    required this.name,
    required this.amount,
    required this.spent,
    required this.remaining,
    required this.usedPct,
    required this.status,
    required this.daysLeft,
    this.categoryId,
  });

  factory BudgetProgressDto.fromJson(Map<String, dynamic> json) =>
      BudgetProgressDto(
        budgetId: json['budget_id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toInt(),
        spent: (json['spent'] as num).toInt(),
        remaining: (json['remaining'] as num).toInt(),
        usedPct: (json['used_pct'] as num).toDouble(),
        status: json['status'] as String,
        daysLeft: (json['days_left'] as num).toInt(),
        categoryId: json['category_id'] as String?,
      );

  final String budgetId;
  final String name;
  final int amount;
  final int spent;
  final int remaining;
  final double usedPct;

  /// 'ok' | 'warning' | 'over'
  final String status;
  final int daysLeft;
  final String? categoryId;
}

class CategoryTotalDto {
  const CategoryTotalDto({
    required this.id,
    required this.name,
    required this.total,
    required this.pct,
  });

  factory CategoryTotalDto.fromJson(Map<String, dynamic> json) =>
      CategoryTotalDto(
        id: json['id'] as String?,
        name: json['name'] as String,
        total: (json['total'] as num).toInt(),
        pct: (json['pct'] as num).toDouble(),
      );

  final String? id;
  final String name;
  final int total;
  final double pct;
}

class DayTotalDto {
  const DayTotalDto({required this.date, required this.total});

  factory DayTotalDto.fromJson(Map<String, dynamic> json) => DayTotalDto(
        date: json['date'] as String,
        total: (json['total'] as num).toInt(),
      );

  final String date;
  final int total;
}

/// `/v1/reports/month-summary`.
class MonthSummaryDto {
  const MonthSummaryDto({
    required this.periodStart,
    required this.periodEnd,
    required this.daysLeft,
    required this.income,
    required this.expense,
    required this.remaining,
    required this.dailyLimit,
    required this.budgetTotal,
    required this.budgetUsedPct,
    required this.previousExpense,
    required this.deltaPct,
    required this.byCategory,
    required this.byDay,
  });

  factory MonthSummaryDto.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>;
    final budget = json['budget'] as Map<String, dynamic>;
    final previous = json['previous'] as Map<String, dynamic>?;
    return MonthSummaryDto(
      periodStart: period['start'] as String,
      periodEnd: period['end'] as String,
      daysLeft: (period['days_left'] as num).toInt(),
      income: (json['income'] as num).toInt(),
      expense: (json['expense'] as num).toInt(),
      remaining: (json['remaining'] as num).toInt(),
      dailyLimit: (json['daily_limit'] as num).toInt(),
      budgetTotal: (budget['total'] as num).toInt(),
      budgetUsedPct: (budget['used_pct'] as num).toDouble(),
      previousExpense: (previous?['expense'] as num?)?.toInt() ?? 0,
      deltaPct: (previous?['delta_pct'] as num?)?.toInt(),
      byCategory: (json['by_category'] as List<dynamic>)
          .map((item) => CategoryTotalDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      byDay: (json['by_day'] as List<dynamic>)
          .map((item) => DayTotalDto.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String periodStart;
  final String periodEnd;
  final int daysLeft;
  final int income;
  final int expense;
  final int remaining;
  final int dailyLimit;
  final int budgetTotal;
  final double budgetUsedPct;
  final int previousExpense;

  /// `null` khi tháng trước không có chi tiêu — chưa so sánh được.
  final int? deltaPct;
  final List<CategoryTotalDto> byCategory;
  final List<DayTotalDto> byDay;
}

class MeDto {
  const MeDto({
    required this.id,
    required this.displayName,
    required this.plan,
    required this.currency,
    required this.timezone,
    this.email,
    this.phone,
    this.username,
    this.hasAvatar = false,
    this.avatarUpdatedAt,
    this.createdAt,
  });

  factory MeDto.fromJson(Map<String, dynamic> json) => MeDto(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        plan: json['plan'] as String,
        currency: json['currency'] as String,
        timezone: json['timezone'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        username: json['username'] as String?,
        hasAvatar: json['has_avatar'] as bool? ?? false,
        avatarUpdatedAt: _parseDate(json['avatar_updated_at']),
        createdAt: _parseDate(json['created_at']),
      );

  final String id;
  final String displayName;
  final String plan;
  final String currency;
  final String timezone;
  final String? email;
  final String? phone;
  final String? username;
  final bool hasAvatar;
  final DateTime? avatarUpdatedAt;
  final DateTime? createdAt;

  /// Chữ cái đầu để hiển thị khi chưa có ảnh đại diện.
  String get initials {
    final source = displayName.trim().isEmpty ? (email ?? '?') : displayName;
    final parts = source.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
/// Một tin trong hộp thư thông báo.
class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) => NotificationDto(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'system',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
        readAt: _parseDate(json['read_at']),
      );

  final String id;

  /// 'budget_alert' | 'daily_reminder' | 'weekly_report' | 'monthly_report'
  /// | 'winback' | 'system'
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;
}

class NotificationListDto {
  const NotificationListDto({required this.items, required this.unreadCount});

  factory NotificationListDto.fromJson(Map<String, dynamic> json) =>
      NotificationListDto(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => NotificationDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      );

  final List<NotificationDto> items;
  final int unreadCount;
}

/// `/v1/goals` — mục tiêu tiết kiệm (thử thách tiết kiệm ở trang chủ).
class GoalDto {
  const GoalDto({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.progressPct,
    required this.isCompleted,
    required this.rev,
    this.deadline,
    this.icon,
  });

  factory GoalDto.fromJson(Map<String, dynamic> json) => GoalDto(
        id: json['id'] as String,
        name: json['name'] as String,
        targetAmount: (json['target_amount'] as num).toInt(),
        savedAmount: (json['saved_amount'] as num?)?.toInt() ?? 0,
        progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
        isCompleted: json['is_completed'] as bool? ?? false,
        rev: (json['rev'] as num?)?.toInt() ?? 1,
        deadline: json['deadline'] as String?,
        icon: json['icon'] as String?,
      );

  final String id;
  final String name;
  final int targetAmount;
  final int savedAmount;
  final double progressPct;
  final bool isCompleted;
  final int rev;
  final String? deadline;
  final String? icon;

  /// Số còn thiếu để đạt mục tiêu, không âm.
  int get missing {
    final left = targetAmount - savedAmount;
    return left < 0 ? 0 : left;
  }
}
