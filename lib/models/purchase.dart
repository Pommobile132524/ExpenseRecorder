import 'purchase_item.dart';

class Purchase {
  final String id;
  final String billNo;
  final String customerId;
  final double totalAmount;
  final String? note;
  final DateTime createdAt;
  final List<PurchaseItem> items;

  Purchase({
    required this.id,
    required this.billNo,
    required this.customerId,
    required this.totalAmount,
    this.note,
    required this.createdAt,
    this.items = const [],
  });

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: json['id'] as String,
        billNo: json['bill_no'] as String,
        customerId: json['customer_id'] as String,
        totalAmount: (json['total_amount'] as num).toDouble(),
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        items: (json['purchase_items'] as List<dynamic>? ?? [])
            .map((e) => PurchaseItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
