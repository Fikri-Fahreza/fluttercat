import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null;

  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  // Load token from storage on app start
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      await fetchMe();
    }
    notifyListeners();
  }

  Future<void> fetchMe() async {
    try {
      final res = await _dio.get(
        '/api/user/profile',
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      _user = res.data['user'];
      notifyListeners();
    } catch (e) {
      _token = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      notifyListeners();
    }
  }

  Future<String?> login(String emailOrUsername, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _dio.post(ApiConfig.login, data: {
        'login': emailOrUsername,
        'password': password,
      });
      _token = res.data['access_token'];
      _user = res.data['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      notifyListeners();
      return null; // success
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Login gagal';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> register(String name, String username, String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _dio.post(ApiConfig.register, data: {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
        'password_confirmation': password,
      });
      _token = res.data['access_token'];
      _user = res.data['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      notifyListeners();
      return null; // success
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Registrasi gagal';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(
        ApiConfig.logout,
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
    } catch (_) {}
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }
}
