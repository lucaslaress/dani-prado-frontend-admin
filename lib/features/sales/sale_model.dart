// Métodos de pagamento aceitos pelo backend
enum PaymentMethod {
  cash('Dinheiro', 'cash'),
  pix('PIX', 'pix'),
  creditCard('Cartão de Crédito', 'credit_card'),
  debitCard('Cartão de Débito', 'debit_card'),
  other('Outro', 'other');

  final String label;

  // Valor enviado ao backend (snake_case conforme o schema do Fastify)
  final String apiValue;

  const PaymentMethod(this.label, this.apiValue);
}

// Uma entrada de pagamento (método + valor)
class PaymentEntry {
  final PaymentMethod method;
  final int amountInCents;

  const PaymentEntry({required this.method, required this.amountInCents});

  double get amount => amountInCents / 100;

  Map<String, dynamic> toJson() => {
        'method': method.apiValue,
        'amountInCents': amountInCents,
      };
}

// Um item no carrinho local (antes de enviar ao backend)
class CartItem {
  final String variantCode;
  final String productName;
  final String color;
  final String size;
  final int unitPriceInCents;
  int quantity;

  CartItem({
    required this.variantCode,
    required this.productName,
    required this.color,
    required this.size,
    required this.unitPriceInCents,
    this.quantity = 1,
  });

  int get totalInCents => unitPriceInCents * quantity;
  double get unitPrice => unitPriceInCents / 100;
  double get total => totalInCents / 100;

  Map<String, dynamic> toJson() => {
        'variantCode': variantCode,
        'quantity': quantity,
      };
}

// Cliente avulso (sem cadastro)
class WalkInCustomer {
  final String name;
  final String phone;

  const WalkInCustomer({required this.name, required this.phone});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
}

// Item de uma venda já concluída (vindo do backend)
class SaleItemModel {
  final String productName;
  final String variantCode;
  final String variantColor;
  final String variantSize;
  final int quantity;
  final int unitPriceInCents;
  final int totalInCents;

  const SaleItemModel({
    required this.productName,
    required this.variantCode,
    required this.variantColor,
    required this.variantSize,
    required this.quantity,
    required this.unitPriceInCents,
    required this.totalInCents,
  });

  double get unitPrice => unitPriceInCents / 100;

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    return SaleItemModel(
      productName: json['productName'] as String,
      variantCode: json['variantCode'] as String,
      variantColor: json['variantColor'] as String,
      variantSize: json['variantSize'] as String,
      quantity: json['quantity'] as int,
      unitPriceInCents: json['unitPriceInCents'] as int,
      totalInCents: json['totalInCents'] as int,
    );
  }
}

// Resposta do backend após criar a venda
class SaleModel {
  final String id;
  final String sellerName;
  final String? customerName;
  final String? walkInCustomerName;
  final int subtotalInCents;
  final int manualDiscountInCents;
  final int totalInCents;
  final String status;
  final String createdAt;
  final List<SaleItemModel> items;
  final List<PaymentEntry> paymentMethods;

  const SaleModel({
    required this.id,
    required this.sellerName,
    required this.customerName,
    required this.walkInCustomerName,
    required this.subtotalInCents,
    this.manualDiscountInCents = 0,
    required this.totalInCents,
    required this.status,
    required this.createdAt,
    this.items = const [],
    this.paymentMethods = const [],
  });

  double get subtotal => subtotalInCents / 100;
  double get discount => manualDiscountInCents / 100;
  double get total => totalInCents / 100;

  // Nome do cliente para exibição
  String get displayCustomer {
    if (customerName != null) return customerName!;
    if (walkInCustomerName != null) return '$walkInCustomerName (avulso)';
    return 'Sem cliente';
  }

  // Rótulo legível do status
  String get statusLabel => switch (status) {
        'completed' => 'Concluída',
        'partially_returned' => 'Dev. parcial',
        'fully_returned' => 'Devolvida',
        _ => status,
      };

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    final walkIn = json['walkInCustomer'] as Map<String, dynamic>?;

    return SaleModel(
      id: json['id'] as String,
      sellerName: json['sellerName'] as String,
      customerName: json['customerName'] as String?,
      walkInCustomerName: walkIn?['name'] as String?,
      subtotalInCents: json['subtotalInCents'] as int,
      manualDiscountInCents: json['manualDiscountInCents'] as int? ?? 0,
      totalInCents: json['totalInCents'] as int,
      status: json['status'] as String,
      createdAt: json['createdAt'] as String,
      items: (json['items'] as List? ?? [])
          .map((i) => SaleItemModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      paymentMethods: (json['paymentMethods'] as List? ?? [])
          .map((p) {
            final map = p as Map<String, dynamic>;
            final method = PaymentMethod.values.firstWhere(
              (m) => m.apiValue == map['method'],
              orElse: () => PaymentMethod.other,
            );
            return PaymentEntry(
              method: method,
              amountInCents: map['amountInCents'] as int,
            );
          })
          .toList(),
    );
  }
}
