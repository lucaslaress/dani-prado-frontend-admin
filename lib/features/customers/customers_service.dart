import '../../core/http/api_client.dart';
import 'customer_model.dart';

class CustomersPage {
  final List<CustomerModel> customers;
  final String? nextCursor;

  const CustomersPage({required this.customers, this.nextCursor});

  factory CustomersPage.fromJson(Map<String, dynamic> json) {
    return CustomersPage(
      customers: (json['customers'] as List)
          .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class CustomersService {
  final ApiClient _api;

  const CustomersService(this._api);

  Future<CustomersPage> listCustomers({
    int limit = 20,
    String? cursor,
    String? search,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (cursor != null) params['cursor'] = cursor;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final query =
        '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    final data = await _api.get('/customers$query') as Map<String, dynamic>;
    return CustomersPage.fromJson(data);
  }

  Future<List<CustomerModel>> getBirthdaysToday() async {
    final data = await _api.get('/customers/birthdays-today') as List;
    return data
        .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CustomerModel>> listAllCustomers() async {
    final data = await _api.get('/customers?limit=1000') as Map<String, dynamic>;
    return (data['customers'] as List)
        .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerModel> getCustomer(String id) async {
    final data = await _api.get('/customers/$id') as Map<String, dynamic>;
    return CustomerModel.fromJson(data);
  }

  Future<CustomerModel> createCustomer(Map<String, dynamic> body) async {
    final data = await _api.post('/customers', body) as Map<String, dynamic>;
    return CustomerModel.fromJson(data);
  }

  Future<CustomerModel> updateCustomer(
      String id, Map<String, dynamic> body) async {
    final data =
        await _api.patch('/customers/$id', body) as Map<String, dynamic>;
    return CustomerModel.fromJson(data);
  }
}
