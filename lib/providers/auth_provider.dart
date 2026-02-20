import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  static const String authServerUrl = 'http://192.168.1.12:5000';
  String? _token;
  String? _username;
  bool _isAuthenticated = false;
  Timer? _heartbeatTimer;

  String? get token => _token;
  String? get username => _username;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _username = prefs.getString('username');

    if (_token != null && _username != null) {
      _isAuthenticated = true;
      _startHeartbeat();
      notifyListeners();
    }
  }

  Future<String?> register(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$authServerUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (response.statusCode == 201) {
        return null; // Success
      } else {
        final data = json.decode(response.body);
        return data['error'] ?? 'Registration failed';
      }
    } catch (e) {
      return 'Cannot connect to server: $e';
    }
  }

  Future<String?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$authServerUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        _username = data['username'];
        _isAuthenticated = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);
        await prefs.setString('username', _username!);

        _startHeartbeat();
        notifyListeners();
        return null; // Success
      } else {
        final data = json.decode(response.body);
        return data['error'] ?? 'Login failed';
      }
    } catch (e) {
      return 'Cannot connect to server: $e';
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (_token != null) {
        try {
          await http.post(
            Uri.parse('$authServerUrl/heartbeat'),
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
            body: json.encode({'ip': '127.0.0.1', 'port': 6001}),
          );
        } catch (e) {
          debugPrint('Heartbeat failed: $e');
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getOnlineUsers() async {
    if (_token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$authServerUrl/users/online'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final users = data['users'] as Map<String, dynamic>;
        return users.entries
            .where((e) => e.key != _username)
            .map((e) => {
          'username': e.key,
          'ip': e.value['ip'],
          'port': e.value['port'],
          'status': e.value['status'],
        })
            .toList();
      }
    } catch (e) {
      debugPrint('Failed to get online users: $e');
    }
    return [];
  }

  Future<void> logout() async {
    if (_token != null) {
      try {
        await http.post(
          Uri.parse('$authServerUrl/logout'),
          headers: {'Authorization': 'Bearer $_token'},
        );
      } catch (e) {
        debugPrint('Logout failed: $e');
      }
    }

    _heartbeatTimer?.cancel();
    _token = null;
    _username = null;
    _isAuthenticated = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('username');

    notifyListeners();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}