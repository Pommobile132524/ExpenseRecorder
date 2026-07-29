class PurchaseItem {
  final String? id;
  final String category;
  final String? description;
  final String? purity;
  final double? weight;
  final double? unitPrice;
  final double amount;
  final List<String> photoPaths;

  PurchaseItem({
    this.id,
    required this.category,
    this.description,
    this.purity,
    this.weight,
    this.unitPrice,
    required this.amount,
    this.photoPaths = const [],
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        id: json['id'] as String?,
        category: json['category'] as String,
        description: json['description'] as String?,
        purity: json['purity'] as String?,
        weight: (json['weight'] as num?)?.toDouble(),
        unitPrice: (json['unit_price'] as num?)?.toDouble(),
        amount: (json['amount'] as num).toDouble(),
        photoPaths: (json['item_photos'] as List<dynamic>? ?? [])
            .map((e) => (e as Map<String, dynamic>)['photo_path'] as String)
            .toList(),
      );

  Map<String, dynamic> toInsertJson(String purchaseId) => {
        'purchase_id': purchaseId,
        'category': category,
        'description': description,
        'purity': purity,
        'weight': weight,
        'unit_price': unitPrice,
        'amount': amount,
      };
}
