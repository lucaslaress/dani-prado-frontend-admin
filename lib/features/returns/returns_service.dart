import '../../core/http/api_client.dart';
import 'return_model.dart';

class ReturnsService {
  final ApiClient _api;
  const ReturnsService(this._api);

  Future<List<ReturnModel>> listReturnsBySale(String saleId) async {
    final data = await _api.get('/returns/sale/$saleId') as List;
    return data
        .map((j) => ReturnModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<ReturnModel> createReturn({
    required String saleId,
    required List<Map<String, dynamic>> items,
    required String reason,
  }) async {
    final data = await _api.post('/returns', {
      'saleId': saleId,
      'items': items,
      'reason': reason,
    }) as Map<String, dynamic>;
    return ReturnModel.fromJson(data);
  }
}
