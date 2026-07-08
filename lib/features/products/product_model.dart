class ProductVariant {
  final String code;
  final String color;
  final String size;
  final int physicalStock;
  final String status;

  const ProductVariant({
    required this.code,
    required this.color,
    required this.size,
    required this.physicalStock,
    required this.status,
  });

  bool get isActive => status == 'active';

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final stock = json['stock'] as Map<String, dynamic>;
    return ProductVariant(
      code: json['code'] as String,
      color: json['color'] as String,
      size: json['size'] as String,
      physicalStock: stock['physicalStore'] as int,
      status: json['status'] as String,
    );
  }
}

class ProductModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final String? brand;
  final int basePriceInCents;
  final int? costPriceInCents;
  final int? promotionalPriceInCents;
  final List<String> images;
  final String status;
  final List<ProductVariant> variants;
  final String createdAt;
  final String updatedAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.brand,
    required this.basePriceInCents,
    required this.costPriceInCents,
    required this.promotionalPriceInCents,
    required this.images,
    required this.status,
    required this.variants,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';

  bool get hasPromotion => promotionalPriceInCents != null;

  // Preço em reais (o backend armazena em centavos)
  double get basePrice => basePriceInCents / 100;
  double? get costPrice =>
      costPriceInCents != null ? costPriceInCents! / 100 : null;
  double? get profitMargin {
    if (costPriceInCents == null) return null;
    final selling = effectivePrice;
    if (selling <= 0) return null;
    return (selling - costPriceInCents! / 100) / selling * 100;
  }
  double? get promotionalPrice =>
      promotionalPriceInCents != null ? promotionalPriceInCents! / 100 : null;

  // Preço efetivo: promocional se existir, senão o base
  double get effectivePrice => promotionalPrice ?? basePrice;

  // Total de peças em estoque somando todas as variantes ativas
  int get totalStock => variants
      .where((v) => v.isActive)
      .fold(0, (sum, v) => sum + v.physicalStock);

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      brand: json['brand'] as String?,
      basePriceInCents: json['basePriceInCents'] as int,
      costPriceInCents: json['costPriceInCents'] as int?,
      promotionalPriceInCents: json['promotionalPriceInCents'] as int?,
      images: List<String>.from(json['images'] as List? ?? []),
      status: json['status'] as String,
      variants: (json['variants'] as List)
          .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}
