import 'dart:convert';

import 'package:http/http.dart' as http;

// --- Exceções tipadas por código HTTP ---

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message);
}

class ForbiddenException extends ApiException {
  const ForbiddenException(super.message);
}

class NotFoundException extends ApiException {
  const NotFoundException(super.message);
}

// --- Cliente HTTP centralizado ---

class ApiClient {
  final String baseUrl;
  final String? Function() getToken;
  final Future<bool> Function()? onUnauthorized;

  const ApiClient({
    required this.baseUrl,
    required this.getToken,
    this.onUnauthorized,
  });

  Map<String, String> get _headers {
    final token = getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path) =>
      _request(() => http.get(Uri.parse('$baseUrl$path'), headers: _headers));

  Future<dynamic> post(String path, Map<String, dynamic> body) => _request(() =>
      http.post(Uri.parse('$baseUrl$path'),
          headers: _headers, body: jsonEncode(body)));

  Future<dynamic> patch(String path, Map<String, dynamic> body) => _request(() =>
      http.patch(Uri.parse('$baseUrl$path'),
          headers: _headers, body: jsonEncode(body)));

  Future<void> delete(String path) =>
      _request(() => http.delete(Uri.parse('$baseUrl$path'), headers: _headers));

  Future<dynamic> _request(Future<http.Response> Function() makeRequest) async {
    final response = await makeRequest();

    if (response.statusCode == 401 && onUnauthorized != null) {
      final refreshed = await onUnauthorized!();
      if (refreshed) {
        final retryResponse = await makeRequest();
        return _handleResponse(retryResponse);
      }
    }

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = 'Erro desconhecido';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['message'] as String? ?? message;
    } catch (_) {}

    switch (response.statusCode) {
      case 401:
        throw UnauthorizedException(message);
      case 403:
        throw const ForbiddenException('Você não tem a permissão necessária');
      case 404:
        throw NotFoundException(message);
      default:
        throw ApiException(message);
    }
  }
}
