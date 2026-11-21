import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/core/session/auth_controller.dart';
import 'package:android/data/remote/dto.dart';
import 'package:android/providers.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Hộp thư thông báo mở từ chuông ở trang chủ.
///
/// Mở màn là đánh dấu tất cả đã đọc: người dùng đã nhìn thấy danh sách, giữ
/// badge đỏ sau đó chỉ gây khó chịu. Tin vẫn nằm lại trong danh sách.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Chạy sau khung hình đầu để không chặn việc vẽ danh sách.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());
  }

  Future<void> _markAllRead() async {
    try {
      // Phải chờ danh sách tải xong: lúc màn vừa mở, hộp thư còn đang tải nên
      // chưa biết có tin chưa đọc hay không. Đọc `.value` ngay sẽ luôn thấy
      // null và badge không bao giờ tắt.
      final list = await ref.read(notificationsProvider.future);
      if (list.unreadCount == 0 || !mounted) return;
      await ref.read(financeApiProvider).markAllNotificationsRead();
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
    } catch (_) {
      // Đánh dấu đã đọc là việc phụ: lỗi mạng không được chặn việc đọc tin.
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.notifications)),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpace.md),
                OutlinedButton(
                  onPressed: () => ref.invalidate(notificationsProvider),
                  child: const Text(AppStrings.retry),
                ),
              ],
            ),
          ),
        ),
        data: (list) {
          if (list.items.isEmpty) return const _EmptyNotifications();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.md,
              AppSpace.lg,
              AppSpace.xxl,
            ),
            itemCount: list.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
            itemBuilder: (context, index) =>
                _NotificationTile(item: list.items[index]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final NotificationDto item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              _iconFor(item.type),
              size: 17,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _relativeTime(item.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Thời gian tương đối: người dùng đọc "2 giờ trước" nhanh hơn "20/11 04:12".
  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return AppStrings.notificationJustNow;
    if (diff.inMinutes < 60) {
      return AppStrings.notificationMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) return AppStrings.notificationHoursAgo(diff.inHours);
    if (diff.inDays < 7) return AppStrings.notificationDaysAgo(diff.inDays);
    return '${time.day.toString().padLeft(2, '0')}/'
        '${time.month.toString().padLeft(2, '0')}/${time.year}';
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.bellOff,
              size: 42,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpace.md),
            const Text(
              AppStrings.notificationsEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            const Text(
              AppStrings.notificationsEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String type) => switch (type) {
      'budget_alert' => LucideIcons.triangleAlert,
      'daily_reminder' => LucideIcons.clock,
      'weekly_report' || 'monthly_report' => LucideIcons.chartNoAxesColumn,
      'winback' => LucideIcons.handHeart,
      _ => LucideIcons.info,
    };
