import '../../core/http/api_client.dart';
import 'sale_model.dart';

class SalesService {
  final ApiClient _api;

  const SalesService(this._api);

  Future<SaleModel> createSale({
    required List<CartItem> items,
    required List<PaymentEntry> paymentMethods,
    String? customerId,
    WalkInCustomer? walkInCustomer,
    int manualDiscountInCents = 0,
  }) async {
    final body = <String, dynamic>{
      'items': items.map((i) => i.toJson()).toList(),
      'paymentMethods': paymentMethods.map((p) => p.toJson()).toList(),
      'manualDiscountInCents': manualDiscountInCents,
    };
    if (customerId != null) body['customerId'] = customerId;
    if (walkInCustomer != null) body['walkInCustomer'] = walkInCustomer.toJson();

    final data = await _api.post('/sales', body) as Map<String, dynamic>;
    return SaleModel.fromJson(data);
  }

  Future<List<SaleModel>> listSales({
    String? sellerId,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, String>{};
    if (sellerId != null) params['sellerId'] = sellerId;
    if (customerId != null) params['customerId'] = customerId;
    if (startDate != null) params['startDate'] = startDate.toIso8601String();
    if (endDate != null) params['endDate'] = endDate.toIso8601String();

    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

    final data = await _api.get('/sales$query') as List;
    return data
        .map((json) => SaleModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<SaleModel> getSale(String id) async {
    final data = await _api.get('/sales/$id') as Map<String, dynamic>;
    return SaleModel.fromJson(data);
  }
}
