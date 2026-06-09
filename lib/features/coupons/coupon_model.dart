class CouponModel {
  final String code;
  final String discountType; // 'percentage' | 'fixed'
  final double discountValue;
  final int? minimumOrderInCents;
  final int? maxUses;
  final int currentUses;
  final String status;
  final String startsAt;
  final String? expiresAt;

  const CouponModel({
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minimumOrderInCents,
    required this.maxUses,
    required this.currentUses,
    required this.status,
    required this.startsAt,
    required this.expiresAt,
  });

  bool get isActive => status == 'active';
  bool get isPercentage => discountType == 'percentage';

  String get discountLabel => isPercentage
      ? '${discountValue.toStringAsFixed(0)}% de desconto'
      : 'R\$ ${(discountValue / 100).toStringAsFixed(2)} de desconto';

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      code: json['code'] as String,
      discountType: json['discountType'] as String,
      discountValue: (json['discountValue'] as num).toDouble(),
      minimumOrderInCents: json['minimumOrderInCents'] as int?,
      maxUses: json['maxUses'] as int?,
      currentUses: json['currentUses'] as int,
      status: json['status'] as String,
      startsAt: json['startsAt'] as String,
      expiresAt: json['expiresAt'] as String?,
    );
  }
}
