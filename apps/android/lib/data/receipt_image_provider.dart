import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/providers.dart';

/// Bytes ảnh của một giao dịch, tải một lần rồi giữ.
///
/// Lịch tháng có thể có 30 ô ảnh. Không cache thì mỗi lần đổi tháng hay
/// `setState` là 30 request lại từ đầu; server cũng phải trả 512KB mỗi ảnh.
/// `keepAlive` vì ảnh của tháng cũ vẫn dùng lại khi cuộn qua lại, và
/// `autoDispose` sẽ xoá đúng lúc không ai xem nữa.
final receiptImageProvider =
    FutureProvider.autoDispose.family<Uint8List, String>((ref, id) async {
  ref.keepAlive();
  final item = await ref.read(financeRepositoryProvider).fetchTransaction(id);
  final base64 = item.receiptBase64;
  if (base64 == null || base64.isEmpty) {
    throw StateError('Giao dịch $id không có ảnh');
  }
  return base64Decode(base64);
});
