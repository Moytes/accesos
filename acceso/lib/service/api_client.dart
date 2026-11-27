import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'connectivity_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String _tokenKey = 'auth_token';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedToken;
  VoidCallback? onUnauthorized;
  bool _unauthorizedDispatching = false;
  http.Client? _overrideHttpClient;

  @visibleForTesting
  void configureForTest({http.Client? httpClient}) {
    _overrideHttpClient = httpClient;
    _cachedToken = null;
    _unauthorizedDispatching = false;
  }

  http.Client get _http => _overrideHttpClient ?? http.Client();

  Future<String?> getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }

    try {
      final secureToken = await _secureStorage.read(key: _tokenKey);
      if (secureToken != null && secureToken.isNotEmpty) {
        _cachedToken = secureToken;
        return _cachedToken;
      }
    } on MissingPluginException {
      // Fallback para entorno de pruebas unitarias sin plugin nativo
    } catch (e) {
      debugPrint('SecureStorage read warning: $e');
    }

    // Migración transparente desde versiones anteriores que guardaban el JWT en SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyToken = prefs.getString(_tokenKey);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        await setToken(legacyToken);
        await prefs.remove(_tokenKey);
        return _cachedToken;
      }
    } catch (_) {}

    return _cachedToken;
  }

  Future<void> setToken(String token) async {
    _cachedToken = token;
    _unauthorizedDispatching = false;

    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } on MissingPluginException {
      // Ignorar en entorno de pruebas unitarias
    } catch (e) {
      debugPrint('SecureStorage write warning: $e');
    }

    // Asegura que no quede copia en texto plano en SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_tokenKey)) {
        await prefs.remove(_tokenKey);
      }
    } catch (_) {}
  }

  Future<void> clearToken() async {
    _cachedToken = null;

    try {
      await _secureStorage.delete(key: _tokenKey);
    } on MissingPluginException {
      // Ignorar en entorno de pruebas unitarias
    } catch (e) {
      debugPrint('SecureStorage delete warning: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  Future<Map<String, String>> _buildHeaders({bool includeAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<http.Response> _send(
    Future<http.Response> Function(http.Client client) action, {
    required bool includeAuth,
  }) async {
    final client = _http;
    final shouldClose = _overrideHttpClient == null;
    try {
      final resp = await action(client).timeout(ApiConfig.requestTimeout);
      ConnectivityService().reportNetworkSuccess();
      await _handleUnauthorized(resp.statusCode, includeAuth);
      return resp;
    } on TimeoutException {
      ConnectivityService().reportNetworkFailure();
      rethrow;
    } on SocketException {
      ConnectivityService().reportNetworkFailure();
      rethrow;
    } on http.ClientException {
      ConnectivityService().reportNetworkFailure();
      rethrow;
    } finally {
      if (shouldClose) {
        client.close();
      }
    }
  }

  Future<http.Response> get(String path, {bool includeAuth = true}) async {
    final headers = await _buildHeaders(includeAuth: includeAuth);
    return _send(
      (client) => client.get(_uri(path), headers: headers),
      includeAuth: includeAuth,
    );
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    bool includeAuth = true,
  }) async {
    final headers = await _buildHeaders(includeAuth: includeAuth);
    return _send(
      (client) => client.post(
        _uri(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      includeAuth: includeAuth,
    );
  }

  Future<http.Response> put(String path, {Object? body}) async {
    final headers = await _buildHeaders();
    return _send(
      (client) => client.put(
        _uri(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      includeAuth: true,
    );
  }

  Future<http.Response> patch(String path, {Object? body}) async {
    final headers = await _buildHeaders();
    return _send(
      (client) => client.patch(
        _uri(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      includeAuth: true,
    );
  }

  Future<http.Response> delete(String path) async {
    final headers = await _buildHeaders();
    return _send(
      (client) => client.delete(_uri(path), headers: headers),
      includeAuth: true,
    );
  }

  Future<http.Response> sendDynamic(
    String method,
    String path, {
    Object? body,
    bool includeAuth = true,
  }) async {
    switch (method.toUpperCase()) {
      case 'GET':
        return get(path, includeAuth: includeAuth);
      case 'PUT':
        return put(path, body: body);
      case 'PATCH':
        return patch(path, body: body);
      case 'DELETE':
        return delete(path);
      case 'POST':
      default:
        return post(path, body: body, includeAuth: includeAuth);
    }
  }

  Future<http.Response> uploadFile(
    String path, {
    required List<int> fileBytes,
    required String fileName,
    Map<String, String> fields = const {},
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    try {
      final streamed = await request.send().timeout(ApiConfig.uploadTimeout);
      final resp = await http.Response.fromStream(streamed);
      ConnectivityService().reportNetworkSuccess();
      await _handleUnauthorized(resp.statusCode, true);
      return resp;
    } on TimeoutException {
      ConnectivityService().reportNetworkFailure();
      rethrow;
    } on SocketException {
      ConnectivityService().reportNetworkFailure();
      rethrow;
    } on http.ClientException {
      ConnectivityService().reportNetworkFailure();
      rethrow;
    }
  }

  Future<void> _handleUnauthorized(int statusCode, bool includeAuth) async {
    if (includeAuth && statusCode == 401) {
      await clearToken();
      if (!_unauthorizedDispatching && onUnauthorized != null) {
        _unauthorizedDispatching = true;
        onUnauthorized!();
      }
    }
  }

  /// Extrae mensajes de error estructurados del backend .NET 10 (`GlobalExceptionHandler` o `ValidationProblemDetails`).
  static String extractErrorMessage(
    http.Response resp, {
    String fallback = 'Error al procesar la solicitud.',
  }) {
    if (resp.body.isEmpty) {
      return '$fallback (HTTP ${resp.statusCode})';
    }
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        final msg = decoded['message']?.toString().trim();
        if (msg != null && msg.isNotEmpty) return msg;

        final errors = decoded['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final firstVal = errors.values.first;
          if (firstVal is List && firstVal.isNotEmpty) {
            return firstVal.first.toString();
          }
          return firstVal.toString();
        }

        final title = decoded['title']?.toString().trim();
        if (title != null && title.isNotEmpty) return title;
      }
    } catch (_) {
      if (resp.body.length < 220) {
        return resp.body.trim();
      }
    }
    return '$fallback (HTTP ${resp.statusCode})';
  }

  static bool isConnectivityError(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException;
  }
}
