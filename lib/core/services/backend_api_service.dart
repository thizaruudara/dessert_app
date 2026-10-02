import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class BackendApiService {
  BackendApiService._();

  static const String _baseUrl = String.fromEnvironment(
    'EDUPEAK_API_BASE_URL',
    defaultValue: 'https://edupeak-web.vercel.app/api',
  );

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> payload, {
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Sign in first.');
      headers['Authorization'] = 'Bearer ${await user.getIdToken()}';
    }
    final response = await http.post(
      Uri.parse('$_baseUrl/$endpoint'),
      headers: headers,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      final message = error is Map ? error['message'] : null;
      throw Exception(message?.toString() ?? 'The request could not be completed.');
    }
    final result = body['result'];
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }
}
