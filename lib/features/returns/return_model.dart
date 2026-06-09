class ReturnItemModel {
  final String variantCode;
  final String productName;
  final int quantity;
  final int unitPriceInCents;
  final int totalInCents;

  const ReturnItemModel({
    required this.variantCode,
    required this.productName,
    required this.quantity,
    required this.unitPriceInCents,
    required this.totalInCents,
  });

  factory ReturnItemModel.fromJson(Map<String, dynamic> json) {
    return ReturnItemModel(
      variantCode: json['variantCode'] as String,
      productName: json['productName'] as String,
      quantity: json['quantity'] as int,
      unitPriceInCents: json['unitPriceInCents'] as int,
      totalInCents: json['totalInCents'] as int,
    );
  }
}

class ReturnModel {
  final String id;
  final String saleId;
  final String processedByName;
  final List<ReturnItemModel> items;
  final int totalRefundedInCents;
  final String reason;
  final String createdAt;

  const ReturnModel({
    required this.id,
    required this.saleId,
    required this.processedByName,
    required this.items,
    required this.totalRefundedInCents,
    required this.reason,
    required this.createdAt,
  });

  double get totalRefunded => totalRefundedInCents / 100;

  factory ReturnModel.fromJson(Map<String, dynamic> json) {
    return ReturnModel(
      id: json['id'] as String,
      saleId: json['saleId'] as String,
      processedByName: json['processedByName'] as String,
      items: (json['items'] as List)
          .map((i) => ReturnItemModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      totalRefundedInCents: json['totalRefundedInCents'] as int,
      reason: json['reason'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}
