import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_service.dart';

class ApiService {
  ApiService(this._authService);
  final AuthService _authService;

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _get(String path) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(),
    );
    if (response.statusCode >= 400) {
      throw Exception(response.body);
    }
    return jsonDecode(response.body);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode >= 400) {
      throw Exception(response.body);
    }
    return jsonDecode(response.body);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode >= 400) {
      throw Exception(response.body);
    }
    return jsonDecode(response.body);
  }

  Future<dynamic> _delete(String path) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(),
    );
    if (response.statusCode >= 400) {
      throw Exception(response.body);
    }
    if (response.body.isEmpty) return {'success': true};
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> createSession() async => _post('/api/auth/session', {});
  Future<List<dynamic>> getMembers() async => (await _get('/api/members')) as List<dynamic>;
  Future<Map<String, dynamic>> addMember(String name, String relation) async =>
      (await _post('/api/members', {'name': name, 'relation': relation})) as Map<String, dynamic>;
  Future<Map<String, dynamic>> getCurrentPrices() async =>
      (await _get('/api/prices/current')) as Map<String, dynamic>;
  Future<Map<String, dynamic>> syncPrices() async =>
      (await _post('/api/prices/sync', {})) as Map<String, dynamic>;
  Future<Map<String, dynamic>> getMemberSummary(int memberId) async =>
      (await _get('/api/members/$memberId/assets-summary')) as Map<String, dynamic>;
  Future<Map<String, dynamic>> getMemberZakat(int memberId) async =>
      (await _get('/api/members/$memberId/zakat')) as Map<String, dynamic>;
  Future<List<dynamic>> getMemberAssets(int memberId) async =>
      (await _get('/api/members/$memberId/assets')) as List<dynamic>;
  Future<Map<String, dynamic>> addAsset({
    required int memberId,
    required String assetType,
    required String karat,
    required double weightG,
    required double purchasePrice,
    required String purchaseDate,
    int? companyId,
  }) async =>
      (await _post('/api/members/$memberId/assets', {
        'asset_type': assetType,
        'karat': karat,
        'weight_g': weightG,
        'purchase_price': purchasePrice,
        'purchase_date': purchaseDate,
        'company_id': companyId,
      })) as Map<String, dynamic>;
  Future<Map<String, dynamic>> updateAsset({
    required int assetId,
    required String assetType,
    required String karat,
    required double weightG,
    required double purchasePrice,
    required String purchaseDate,
    int? companyId,
  }) async =>
      (await _put('/api/assets/$assetId', {
        'asset_type': assetType,
        'karat': karat,
        'weight_g': weightG,
        'purchase_price': purchasePrice,
        'purchase_date': purchaseDate,
        'company_id': companyId,
      })) as Map<String, dynamic>;
  Future<void> deleteAsset(int assetId) async {
    await _delete('/api/assets/$assetId');
  }

  Future<Map<String, dynamic>> getSavings(int memberId) async =>
      (await _get('/api/members/$memberId/savings')) as Map<String, dynamic>;
  Future<Map<String, dynamic>> addSaving(int memberId, double amount) async => (await _post(
        '/api/members/$memberId/savings',
        {'amount': amount, 'currency': 'EGP'},
      )) as Map<String, dynamic>;
  Future<List<dynamic>> getGoals(int memberId) async =>
      (await _get('/api/members/$memberId/goals')) as List<dynamic>;
  Future<Map<String, dynamic>> createGoal({
    required int memberId,
    required String karat,
    required double targetWeightG,
    required double savedAmount,
    int? companyId,
  }) async =>
      (await _post('/api/goals/calculate', {
        'member_id': memberId,
        'karat': karat,
        'target_weight_g': targetWeightG,
        'saved_amount': savedAmount,
        'company_id': companyId,
      })) as Map<String, dynamic>;
  Future<Map<String, dynamic>> updateGoalSaved({
    required int goalId,
    required double savedAmount,
  }) async =>
      (await _put('/api/goals/$goalId/saved', {
        'saved_amount': savedAmount,
      })) as Map<String, dynamic>;
  Future<List<dynamic>> getCompanies() async => (await _get('/api/companies')) as List<dynamic>;
  Future<Map<String, dynamic>> addCompany(String name) async =>
      (await _post('/api/companies', {'name': name})) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateSettings({
    required String locale,
    required String theme,
    required int notificationIntervalHours,
  }) async =>
      (await _put('/api/me/settings', {
        'locale': locale,
        'theme': theme,
        'notification_interval_hours': notificationIntervalHours,
      })) as Map<String, dynamic>;
}
