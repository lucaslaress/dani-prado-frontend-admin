import '../../core/http/api_client.dart';
import 'customer_model.dart';

class CustomersService {
  final ApiClient _api;

  const CustomersService(this._api);

  Future<List<CustomerModel>> listCustomers({String? search}) async {
    final path = search != null && search.isNotEmpty
        ? '/customers?search=${Uri.encodeComponent(search)}'
        : '/customers';
    final data = await _api.get(path) as List;
    return data
        .map((json) => CustomerModel.fromJson(json as Map<String, dynamic>))
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
