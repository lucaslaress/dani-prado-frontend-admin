import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

const _tokenKey = 'auth_token';

// Modelo que representa o usuário logado
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final List<String> permissions;
  final String status;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    required this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      permissions: List<String>.from(json['permissions'] as List),
      status: json['status'] as String,
    );
  }

  bool get isAdmin => role == 'admin';

  bool hasPermission(String permission) => permissions.contains(permission);
}

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _isLoading = false;
  bool _isInitialized = false;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _token != null && _user != null;

  AuthProvider() {
    _tryAutoLogin();
  }

  // Tenta recuperar a sessão salva ao abrir o app
  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);

    if (savedToken == null) {
      _isInitialized = true;
      notifyListeners();
      return;
    }

    final userData = await _fetchCurrentUser(savedToken, silent: true);

    if (userData != null) {
      _token = savedToken;
      _user = userData;
    } else {
      await prefs.remove(_tokenKey);
    }

    _isInitialized = true;
    notifyListeners();
  }

  // Faz login chamando o backend
  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.backendUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw body['message'] as String? ?? 'Erro ao fazer login';
      }

      final loginData = jsonDecode(response.body) as Map<String, dynamic>;
      final receivedToken = loginData['token'] as String;

      final userData = await _fetchCurrentUser(receivedToken);
      if (userData == null) throw 'Não foi possível carregar os dados do usuário';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, receivedToken);

      _token = receivedToken;
      _user = userData;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Busca os dados do usuário logado no backend.
  // Lança exceção com a mensagem real do backend se falhar.
  // Retorna null apenas se chamado durante auto-login (sessão expirada).
  Future<UserModel?> _fetchCurrentUser(String token,
      {bool silent = false}) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.backendUrl}/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        if (silent) return null;
        String message = 'Erro ao carregar perfil do usuário';
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          message = body['message'] as String? ?? message;
        } catch (_) {}
        throw message;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return UserModel.fromJson(json);
    } catch (e) {
      if (silent) return null;
      rethrow;
    }
  }

  // Faz logout limpando o token do disco e da memória
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);

    _token = null;
    _user = null;
    notifyListeners();
  }
}
