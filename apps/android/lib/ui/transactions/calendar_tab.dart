import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/data/receipt_image_provider.dart';
import 'package:android/domain/models.dart';
import 'package:android/domain/month_grid.dart';
import 'package:android/providers.dart';
import 'package:android/ui/common/cards.dart';
import 'package:android/ui/common/state_views.dart';
import 'package:android/ui/format.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Sổ ảnh chi tiêu: một tháng nhìn như cuốn nhật ký.
///
/// Ô ngày ưu tiên ảnh hơn con số — đó là toàn bộ lý do màn này tồn tại. Ngày
/// không có ảnh thì hiện tổng chi, để lịch không thành một lưới trống.
/// Chỉ là phần thân: khung và AppBar do tab Giao dịch giữ, để nút chuyển
/// Danh sách/Lịch nằm cùng một chỗ thay vì mọc thêm AppBar thứ hai.
class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month);
  }

  void _shift(int months) {
    setState(() => _anchor = DateTime(_anchor.year, _anchor.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final grid = MonthGrid.of(_anchor);
    final async = ref.watch(
      monthTransactionsProvider((year: _anchor.year, month: _anchor.month)),
    );
    final now = DateTime.now();
    final isCurrentMonth = now.year == _anchor.year && now.month == _anchor.month;

    return async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(
            monthTransactionsProvider((year: _anchor.year, month: _anchor.month)),
          ),
        ),
        data: (items) {
          final cells = buildMonthCells(
            grid: grid,
            now: now,
            items: items.map(
              (item) => (
                occurredAt: item.occurredAt ?? now,
                amount: item.amount,
                isExpense: item.type != TransactionType.income,
                id: item.id,
                hasPhoto: item.hasReceipt,
              ),
            ),
          );
          final filled = cells.whereType<DayCell>().toList();
          final monthExpense = filled.fold<int>(0, (sum, c) => sum + c.expense);
          final photoCount = filled.where((c) => c.hasPhoto).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.xl,
            ),
            children: [
              _MonthHeader(
                grid: grid,
                expense: monthExpense,
                photoCount: photoCount,
                onPrevious: () => _shift(-1),
                onNext: () => _shift(1),
                canGoNext: !isCurrentMonth,
                onToday: isCurrentMonth
                    ? null
                    : () => setState(
                          () => _anchor = DateTime(now.year, now.month),
                        ),
              ),
              // Tháng trống thì nói ngay dưới tiêu đề tháng. Đặt dưới lưới
              // thì trên máy 360x640 người dùng phải cuộn mới thấy, mà thấy
              // một lưới trắng không lời giải thích thì dễ tưởng app lỗi.
              if (monthExpense == 0) ...[
                const SizedBox(height: AppSpace.sm),
                _InlineHint(
                  icon: LucideIcons.calendarPlus,
                  message: AppStrings.calendarEmptyMonth,
                ),
              ],
              const SizedBox(height: AppSpace.lg),
              _WeekdayRow(),
              const SizedBox(height: AppSpace.xs),
              _MonthGrid(
                grid: grid,
                cells: cells,
                maxExpense: filled.fold<int>(
                  0,
                  (max, c) => c.expense > max ? c.expense : max,
                ),
              ),
              if (monthExpense > 0 && photoCount == 0) ...[
                const SizedBox(height: AppSpace.lg),
                _InlineHint(
                  icon: LucideIcons.camera,
                  message: AppStrings.calendarNoPhotoHint,
                ),
              ],
            ],
          );
        },
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.grid,
    required this.expense,
    required this.photoCount,
    required this.onPrevious,
    required this.onNext,
    required this.canGoNext,
    this.onToday,
  });

  final MonthGrid grid;
  final int expense;
  final int photoCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoNext;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(LucideIcons.chevronLeft),
          tooltip: 'Tháng trước',
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                AppStrings.calendarMonthLabel(grid.month, grid.year),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '${formatMoney(expense)} · ${AppStrings.calendarPhotoCount(photoCount)}',
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Đứng ở tháng hiện tại thì không có tháng sau để đi — nút mờ đi thay
        // vì biến thành nút khác, để người dùng không phải đoán lại từ đầu.
        IconButton(
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(LucideIcons.chevronRight),
          tooltip: 'Tháng sau',
        ),
        if (onToday != null)
          TextButton(
            onPressed: onToday,
            child: const Text(AppStrings.calendarToday),
          )
        else
          const SizedBox(width: 12),
      ],
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final label in AppStrings.calendarWeekdays)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.grid,
    required this.cells,
    required this.maxExpense,
  });

  final MonthGrid grid;
  final List<DayCell?> cells;
  final int maxExpense;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var week = 0; week < cells.length ~/ 7; week++) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _DayCellView(
                      cell: cells[week * 7 + column],
                      maxExpense: maxExpense,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _DayCellView extends StatelessWidget {
  const _DayCellView({required this.cell, required this.maxExpense});

  final DayCell? cell;
  final int maxExpense;

  @override
  Widget build(BuildContext context) {
    final value = cell;
    if (value == null) return const SizedBox(height: 64);

    // Cường độ màu theo mức chi trong tháng: ngày nặng nhất đậm nhất. Đây là
    // tín hiệu phụ, số tiền vẫn đọc được nên màu không phải kênh duy nhất.
    final ratio = maxExpense == 0 ? 0.0 : value.expense / maxExpense;
    final tint = value.expense == 0
        ? AppColors.neutralSoft
        : Color.lerp(AppColors.primarySoft, const Color(0xFFBFE0C6), ratio)!;

    return Semantics(
      button: true,
      label: '${value.day}/${value.date.month}: '
          '${value.isEmpty ? 'chưa ghi khoản nào' : formatMoney(value.expense)}'
          '${value.hasPhoto ? ', có ảnh' : ''}',
      child: InkWell(
        onTap: () => openDayTransactions(context, value),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: value.hasPhoto ? AppColors.surface : tint,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: value.isToday ? AppColors.primary : AppColors.divider,
              width: value.isToday ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: value.hasPhoto
              ? _PhotoCell(cell: value)
              : _NoPhotoCell(cell: value),
        ),
      ),
    );
  }
}

/// Ô có ảnh: ảnh phủ kín ô, số ngày và số tiền nằm trên một dải tối.
///
/// Chữ trắng trên dải tối thay vì chữ màu: ảnh nào cũng có vùng sáng, chữ
/// không có nền sẽ mất hút đúng ở những ảnh đẹp nhất.
class _PhotoCell extends ConsumerWidget {
  const _PhotoCell({required this.cell});

  final DayCell cell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receiptImageProvider(cell.photoTransactionId!));
    return Stack(
      fit: StackFit.expand,
      children: [
        async.when(
          loading: () => Container(color: AppColors.neutralSoft),
          error: (_, _) => Container(
            color: AppColors.primarySoft,
            child: const Icon(
              LucideIcons.imageOff,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
          data: (bytes) => Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // Ô 64px: giải mã ở kích thước gốc rồi thu nhỏ là phí bộ nhớ trên
            // máy 4GB RAM, nhất là khi cả tháng đều có ảnh.
            cacheWidth: 160,
            // Ảnh hỏng vẫn xảy ra thật (tải lên lỗi, tệp rỗng, định dạng
            // lạ). Không có nhánh này thì Flutter vẽ nguyên chuỗi
            // "Exception: Could not decompress image." vào ô lịch.
            errorBuilder: (_, _, _) => Container(
              color: AppColors.primarySoft,
              child: const Icon(
                LucideIcons.imageOff,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xCC000000)],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${cell.day}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Flexible(
                  child: Text(
                    formatMoneyShort(cell.expense),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (cell.isToday)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _NoPhotoCell extends StatelessWidget {
  const _NoPhotoCell({required this.cell});

  final DayCell cell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${cell.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: cell.isToday ? FontWeight.w800 : FontWeight.w600,
              color: cell.isEmpty
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (cell.expense > 0)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoneyShort(cell.expense),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineHint extends StatelessWidget {
  const _InlineHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mở danh sách các khoản của một ngày. Tách màn riêng thay vì sheet: một
/// ngày có thể có cả chục khoản, sheet sẽ phải cuộn trong sheet.
Future<void> openDayTransactions(BuildContext context, DayCell cell) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => DayTransactionsScreen(cell: cell)),
  );
}

class DayTransactionsScreen extends ConsumerWidget {
  const DayTransactionsScreen({super.key, required this.cell});

  final DayCell cell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dùng chung provider của tháng với lịch: mở danh sách ngày không tải
    // lại tháng vừa xem, và dữ liệu hai màn không lệch nhau.
    final async = ref.watch(
      monthTransactionsProvider((year: cell.date.year, month: cell.date.month)),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${cell.day.toString().padLeft(2, '0')}/'
          '${cell.date.month.toString().padLeft(2, '0')}',
        ),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(
            monthTransactionsProvider(
              (year: cell.date.year, month: cell.date.month),
            ),
          ),
        ),
        data: (items) {
          final ofDay = items
              .where(
                (item) =>
                    item.occurredAt != null &&
                    MonthGrid.keyOf(item.occurredAt!) == MonthGrid.keyOf(cell.date),
              )
              .toList();
          if (ofDay.isEmpty) {
            return EmptyView(message: AppStrings.calendarDayEmpty);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.md,
              AppSpace.lg,
              AppSpace.xl,
            ),
            children: [
              Row(
                children: [
                  Text(
                    AppStrings.calendarDayTotal,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    formatMoney(cell.expense),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                child: Column(
                  children: ofDay
                      .map(
                        (item) => TransactionTile(
                          key: ValueKey(item.id),
                          item: item,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
