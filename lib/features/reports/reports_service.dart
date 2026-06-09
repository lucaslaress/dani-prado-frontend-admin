import '../../core/http/api_client.dart';

class ReportsService {
  final ApiClient _api;
  const ReportsService(this._api);

  Future<Map<String, dynamic>> getSalesSummary(
      DateTime startDate, DateTime endDate) async {
    final start = Uri.encodeComponent(startDate.toIso8601String());
    final end = Uri.encodeComponent(endDate.toIso8601String());
    return await _api.get('/reports/sales/summary?startDate=$start&endDate=$end')
        as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTopProducts(
      DateTime startDate, DateTime endDate) async {
    final start = Uri.encodeComponent(startDate.toIso8601String());
    final end = Uri.encodeComponent(endDate.toIso8601String());
    return await _api.get(
        '/reports/sales/top-products?startDate=$start&endDate=$end') as List;
  }

  Future<List<dynamic>> getDailySales() async {
    return await _api.get('/reports/sales/daily') as List;
  }

  Future<List<dynamic>> getLowStock() async {
    return await _api.get('/reports/stock/low') as List;
  }

  Future<List<dynamic>> getSalesBySeller(
      DateTime startDate, DateTime endDate) async {
    final start = Uri.encodeComponent(startDate.toIso8601String());
    final end = Uri.encodeComponent(endDate.toIso8601String());
    return await _api.get(
        '/reports/sales/by-seller?startDate=$start&endDate=$end') as List;
  }
}
