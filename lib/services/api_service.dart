import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class ApiService {
  // 🔴 PRODUCCIÓN (AWS):
  static const String baseUrl = 'http://52.86.220.76:3000';
  // 🟢 LOCAL (desarrollo): 
  // static const String baseUrl = 'http://10.53.159.7:3000';

  static const String _keyToken = 'auth_token';
  static const String _keyRole = 'user_role';
  static const String _keyName = 'user_name';
  static const String _keyId = 'user_id';

  static Future<void> saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, data['token'] ?? '');
    await prefs.setString(_keyRole, data['role'] ?? '');
    await prefs.setString(_keyName, data['name'] ?? '');
    if (data['id'] != null) await prefs.setInt(_keyId, data['id']);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyName);
    await prefs.remove(_keyId);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _parse(http.Response r) {
    if (r.body == 'null') {
      return {}; // Evitar crash si el body es "null" literal
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 400) {
      throw ApiException(body['error'] ?? 'Error del servidor', r.statusCode);
    }
    return body;
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> postAuth(
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = await _authHeaders();
    final res = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _parse(res);
  }

  static Future<List<dynamic>> getList(String path) async {
    final headers = await _authHeaders();
    final res = await http
        .get(Uri.parse('$baseUrl$path'), headers: headers)
        .timeout(const Duration(seconds: 30));
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error'] ?? 'Error del servidor', res.statusCode);
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getMap(String path) async {
    final headers = await _authHeaders();
    final res = await http
        .get(Uri.parse('$baseUrl$path'), headers: headers)
        .timeout(const Duration(seconds: 30));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> get(String path) => getMap(path);

  /// Alias semántico para PUT con auth (idéntico a put())
  static Future<Map<String, dynamic>> putAuth(
    String path,
    Map<String, dynamic> body,
  ) => put(path, body);

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = await _authHeaders();
    final res = await http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = await _authHeaders();
    final res = await http
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final headers = await _authHeaders();
    final res = await http
        .delete(Uri.parse('$baseUrl$path'), headers: headers)
        .timeout(const Duration(seconds: 30));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> uploadFile(
    String path,
    String filePath,
  ) async {
    final token = await getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));

    request.headers.addAll({
      if (token != null) 'Authorization': 'Bearer $token',
    });

    final xFile = XFile(filePath);
    final bytes = await xFile.readAsBytes();
    final filename = xFile.name.isNotEmpty ? xFile.name : 'image.jpg';

    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: filename),
    );

    final streamedRes = await request.send().timeout(
      const Duration(seconds: 30),
    );
    final res = await http.Response.fromStream(streamedRes);
    return _parse(res);
  }

  static Future<String> login(String email, String password) async {
    final trimmed = email.trim().toLowerCase();

    final endpoints = [
      '/auth/login/admin',
      '/auth/login/restaurant',
      '/auth/login/client',
      '/auth/login/rider',
    ];

    Object? lastError;
    for (final ep in endpoints) {
      try {
        final data = await post(ep, {'email': trimmed, 'password': password});
        await saveSession(data);
        return data['role'] as String;
      } catch (e) {
        lastError = e;
        if (e is ApiException && e.statusCode == 401) continue;
        if (e is ApiException && e.statusCode == 403) rethrow;
        rethrow;
      }
    }
    throw lastError ?? ApiException('Credenciales incorrectas', 401);
  }

  static Future<String> registerClient({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final data = await post('/auth/register/client', {
      'name': name,
      'email': email.trim().toLowerCase(),
      'password': password,
      'phone': phone,
    });
    await saveSession(data);
    return data['role'] as String;
  }

  static Future<void> logout() => clearSession();
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}






