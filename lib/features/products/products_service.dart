import '../../core/http/api_client.dart';
import 'product_model.dart';

class ProductsService {
  final ApiClient _api;

  const ProductsService(this._api);

  Future<List<ProductModel>> listProducts() async {
    final data = await _api.get('/products') as List;
    return data
        .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ProductModel> getProduct(String id) async {
    final data = await _api.get('/products/$id') as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }

  Future<ProductModel> getProductByVariantCode(String code) async {
    final data =
        await _api.get('/products/variant/$code') as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }

  Future<ProductModel> createProduct(Map<String, dynamic> body) async {
    final data = await _api.post('/products', body) as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }

  Future<ProductModel> updateProduct(
      String id, Map<String, dynamic> body) async {
    final data =
        await _api.patch('/products/$id', body) as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }

  Future<void> deactivateProduct(String id) async {
    await _api.patch('/products/$id/deactivate', {});
  }
}
