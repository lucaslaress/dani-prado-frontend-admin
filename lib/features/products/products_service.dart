import '../../core/http/api_client.dart';
import 'product_model.dart';

class ProductsPage {
  final List<ProductModel> products;
  final String? nextCursor;

  const ProductsPage({required this.products, this.nextCursor});

  factory ProductsPage.fromJson(Map<String, dynamic> json) {
    return ProductsPage(
      products: (json['products'] as List)
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class ProductsService {
  final ApiClient _api;

  const ProductsService(this._api);

  Future<ProductsPage> listProducts({
    int limit = 20,
    String? cursor,
    String? search,
    String? brand,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (cursor != null) params['cursor'] = cursor;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (brand != null && brand.isNotEmpty) params['brand'] = brand;
    final query =
        '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    final data = await _api.get('/products$query') as Map<String, dynamic>;
    return ProductsPage.fromJson(data);
  }

  Future<List<String>> listBrands() async {
    final data = await _api.get('/products/brands') as List;
    return data.cast<String>();
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
