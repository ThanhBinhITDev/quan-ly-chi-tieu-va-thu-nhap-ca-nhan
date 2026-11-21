import 'models.dart';

/// Kết quả kiểm tra dữ liệu nhập vào form giao dịch.
class TransactionValidation {
  const TransactionValidation({this.amountError});

  final String? amountError;

  bool get isValid => amountError == null;
}

/// Chuyển chuỗi người dùng nhập thành số tiền VND nguyên.
/// Chấp nhận dấu chấm/phẩy phân cách hàng nghìn, bỏ khoảng trắng.
/// Trả về null nếu không phải số dương.
int? parseAmount(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\s.,]'), '');
  if (cleaned.isEmpty) return null;
  final value = int.tryParse(cleaned);
  if (value == null || value <= 0) return null;
  return value;
}

TransactionValidation validateTransaction({required String rawAmount}) {
  final parsed = parseAmount(rawAmount);
  if (parsed == null) {
    return const TransactionValidation(
      amountError: 'Nhập số tiền lớn hơn 0.',
    );
  }
  return const TransactionValidation();
}

/// Dữ liệu một giao dịch mới trước khi ghi xuống bộ nhớ cục bộ.
class NewTransaction {
  const NewTransaction({
    required this.amount,
    required this.type,
    required this.category,
    required this.wallet,
    required this.note,
    required this.occurredAt,
    this.paymentMethod,
    this.incomeSource,
    this.receiptBase64,
    this.receiptMime,
    this.removeReceipt = false,
  });

  final int amount;
  final TransactionType type;
  final CategoryItem category;
  final String wallet;
  final String note;
  final DateTime occurredAt;
  final String? paymentMethod; // cash|bank_transfer|card|ewallet|other
  final String? incomeSource;
  final String? receiptBase64;
  final String? receiptMime;
  final bool removeReceipt;
}
