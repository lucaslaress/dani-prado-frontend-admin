import '../../core/auth/auth_provider.dart';
import '../../core/http/api_client.dart';

class UsersService {
  final ApiClient _api;
  const UsersService(this._api);

  Future<List<UserModel>> listSellers() async {
    final data = await _api.get('/users/sellers') as List;
    return data
        .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel> createSeller(Map<String, dynamic> body) async {
    final data =
        await _api.post('/users/sellers', body) as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  Future<UserModel> updateSeller(String id, Map<String, dynamic> body) async {
    final data =
        await _api.patch('/users/sellers/$id', body) as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }
}
