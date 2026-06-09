import '../../core/http/api_client.dart';
import 'coupon_model.dart';

class CouponsService {
  final ApiClient _api;
  const CouponsService(this._api);

  Future<List<CouponModel>> listCoupons() async {
    final data = await _api.get('/coupons') as List;
    return data
        .map((j) => CouponModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<CouponModel> createCoupon(Map<String, dynamic> body) async {
    final data = await _api.post('/coupons', body) as Map<String, dynamic>;
    return CouponModel.fromJson(data);
  }

  Future<CouponModel> updateCoupon(
      String code, Map<String, dynamic> body) async {
    final data =
        await _api.patch('/coupons/$code', body) as Map<String, dynamic>;
    return CouponModel.fromJson(data);
  }

  Future<void> deactivateCoupon(String code) async {
    await _api.patch('/coupons/$code/deactivate', {});
  }
}
