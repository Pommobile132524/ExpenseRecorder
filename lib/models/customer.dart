class Customer {
  final String id;
  final String fullName;
  final String nationalIdLast4;
  final String? phone;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.fullName,
    required this.nationalIdLast4,
    this.phone,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        nationalIdLast4: json['national_id_last4'] as String,
        phone: json['phone'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
