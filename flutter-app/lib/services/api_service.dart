import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../config.dart';
import 'auth_service.dart';
import 'database_helper.dart';
import 'gold_scraper.dart';

/// Dual-mode service:
///   • Web  → HTTP calls to localhost Node.js backends (need backends running)
///   • Mobile → local SQLite + direct eDahab scraping (standalone, no backend)
class ApiService {
  ApiService(this._authService) : _isDevBypass = false;

  ApiService.devBypass()
      : _authService = AuthService(),
        _isDevBypass = true;

  final AuthService _authService;
  final bool _isDevBypass;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  String get _userId {
    if (_isDevBypass) return 'dev-user';
    return _authService.currentUser?.uid ?? 'anonymous';
  }

  Future<Database> get _db => _dbHelper.database;
  List<Map<String, dynamic>> _rows(List<Map<String, Object?>> r) =>
      _dbHelper.toDynamic(r);
  Map<String, dynamic> _row(Map<String, Object?> r) =>
      _dbHelper.toDynamicMap(r);

  // ════════════════════════════════════════════════════════════
  //  Web HTTP helpers (only used when kIsWeb)
  // ════════════════════════════════════════════════════════════

  Future<Map<String, String>> _headers() async {
    if (_isDevBypass) return {'Content-Type': 'application/json'};
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _httpGet(String path) async {
    final r = await http.get(Uri.parse('${AppConfig.apiBaseUrl}$path'),
        headers: await _headers());
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  Future<dynamic> _httpPost(String path, Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('${AppConfig.apiBaseUrl}$path'),
        headers: await _headers(), body: jsonEncode(body));
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  Future<dynamic> _httpPut(String path, Map<String, dynamic> body) async {
    final r = await http.put(Uri.parse('${AppConfig.apiBaseUrl}$path'),
        headers: await _headers(), body: jsonEncode(body));
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  Future<dynamic> _httpDelete(String path) async {
    final r = await http.delete(Uri.parse('${AppConfig.apiBaseUrl}$path'),
        headers: await _headers());
    if (r.statusCode >= 400) throw Exception(r.body);
    if (r.body.isEmpty) return {'success': true};
    return jsonDecode(r.body);
  }

  // ════════════════════════════════════════════════════════════
  //  Session
  // ════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> createSession() async {
    if (kIsWeb)
      return (await _httpPost('/api/auth/session', {})) as Map<String, dynamic>;
    return {
      'user': {'uid': _userId},
      'auth': {'uid': _userId}
    };
  }

  // ════════════════════════════════════════════════════════════
  //  Prices
  // ════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getCurrentPrices() async {
    if (kIsWeb)
      return (await _httpGet('/api/prices/current')) as Map<String, dynamic>;

    final db = await _db;
    final latest =
        await db.query('GoldPriceCache', orderBy: 'id DESC', limit: 1);
    if (latest.isEmpty)
      return {'updated_at': '', 'prices': <String, dynamic>{}};

    final fetchedAt = latest.first['fetched_at'] as String;
    final allRows = await db.query('GoldPriceCache',
        where: 'fetched_at = ?', whereArgs: [fetchedAt]);
    final prices = <String, dynamic>{};
    for (final row in allRows) {
      prices[row['carat'] as String] = {
        'buy_price': row['buy_price'],
        'sell_price': row['sell_price'],
        'currency': row['currency'],
      };
    }
    return {'updated_at': fetchedAt, 'prices': prices};
  }

  Future<Map<String, dynamic>> syncPrices() async {
    if (kIsWeb)
      return (await _httpPost('/api/prices/sync', {})) as Map<String, dynamic>;

    final scraped = await GoldScraper.scrapeGoldPrices();
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.delete('GoldPriceCache');

    final carats = scraped['carats'] as Map<String, dynamic>;
    for (final entry in carats.entries) {
      final v = entry.value as Map;
      await db.insert('GoldPriceCache', {
        'carat': '${entry.key}k',
        'buy_price': v['buy'],
        'sell_price': v['sell'],
        'currency': 'EGP',
        'fetched_at': now,
      });
    }
    if (scraped['goldPoundPrice'] != null) {
      await db.insert('GoldPriceCache', {
        'carat': 'gold_pound_8g',
        'buy_price': scraped['goldPoundPrice'],
        'sell_price': scraped['goldPoundPrice'],
        'currency': 'EGP',
        'fetched_at': now,
      });
    }
    if (scraped['ouncePrice'] != null) {
      await db.insert('GoldPriceCache', {
        'carat': 'ounce',
        'buy_price': scraped['ouncePrice'],
        'sell_price': scraped['ouncePrice'],
        'currency': 'USD',
        'fetched_at': now,
      });
    }

    final rate = await GoldScraper.fetchUsdEgpRate();
    if (rate != null) {
      await db.insert('GoldPriceCache', {
        'carat': 'usd_egp_rate',
        'buy_price': rate,
        'sell_price': rate,
        'currency': 'EGP',
        'fetched_at': now,
      });
    }
    return {'message': 'Price cache updated.'};
  }

  // ════════════════════════════════════════════════════════════
  //  Members
  // ════════════════════════════════════════════════════════════

  Future<List<dynamic>> getMembers() async {
    if (kIsWeb) return (await _httpGet('/api/members')) as List<dynamic>;
    final db = await _db;
    return _rows(await db.query('FamilyMembers',
        where: 'user_id = ?', whereArgs: [_userId], orderBy: 'id DESC'));
  }

  Future<Map<String, dynamic>> addMember(String name,
      [String relation = '']) async {
    if (kIsWeb)
      return (await _httpPost(
              '/api/members', {'name': name, 'relation': relation}))
          as Map<String, dynamic>;
    final db = await _db;
    final id = await db.insert('FamilyMembers', {
      'user_id': _userId,
      'name': name,
      'relation': relation,
      'created_at': DateTime.now().toIso8601String(),
    });
    return _row(
        (await db.query('FamilyMembers', where: 'id = ?', whereArgs: [id]))
            .first);
  }

  Future<Map<String, dynamic>> updateMember(int memberId, String name,
      [String relation = '']) async {
    if (kIsWeb)
      return (await _httpPut(
              '/api/members/$memberId', {'name': name, 'relation': relation}))
          as Map<String, dynamic>;
    final db = await _db;
    await db.update('FamilyMembers', {'name': name, 'relation': relation},
        where: 'id = ? AND user_id = ?', whereArgs: [memberId, _userId]);
    return _row((await db
            .query('FamilyMembers', where: 'id = ?', whereArgs: [memberId]))
        .first);
  }

  Future<void> deleteMember(int memberId) async {
    if (kIsWeb) {
      await _httpDelete('/api/members/$memberId');
      return;
    }
    final db = await _db;
    await db.delete('Assets', where: 'member_id = ?', whereArgs: [memberId]);
    await db.delete('Savings', where: 'member_id = ?', whereArgs: [memberId]);
    await db
        .delete('PurchaseGoals', where: 'member_id = ?', whereArgs: [memberId]);
    await db.delete('FamilyMembers',
        where: 'id = ? AND user_id = ?', whereArgs: [memberId, _userId]);
  }

  // ════════════════════════════════════════════════════════════
  //  Assets
  // ════════════════════════════════════════════════════════════

  Future<List<dynamic>> getMemberAssets(int memberId) async {
    if (kIsWeb)
      return (await _httpGet('/api/members/$memberId/assets')) as List<dynamic>;
    final db = await _db;
    return _rows(await db.query('Assets',
        where: 'member_id = ?', whereArgs: [memberId], orderBy: 'id DESC'));
  }

  Future<Map<String, dynamic>> addAsset({
    required int memberId,
    required String assetType,
    required String karat,
    required double weightG,
    required double purchasePrice,
    required String purchaseDate,
    int? companyId,
    String? invoiceLocalPath,
  }) async {
    if (kIsWeb) {
      return (await _httpPost('/api/members/$memberId/assets', {
        'asset_type': assetType,
        'karat': karat,
        'weight_g': weightG,
        'purchase_price': purchasePrice,
        'purchase_date': purchaseDate,
        'company_id': companyId,
        if (invoiceLocalPath != null) 'invoice_local_path': invoiceLocalPath,
      })) as Map<String, dynamic>;
    }
    final db = await _db;
    final id = await db.insert('Assets', {
      'member_id': memberId,
      'asset_type': assetType,
      'karat': karat,
      'company_id': companyId,
      'weight_g': weightG,
      'purchase_price': purchasePrice,
      'purchase_date': purchaseDate,
      'invoice_local_path': invoiceLocalPath,
      'created_at': DateTime.now().toIso8601String(),
    });
    return _row(
        (await db.query('Assets', where: 'id = ?', whereArgs: [id])).first);
  }

  Future<Map<String, dynamic>> updateAsset({
    required int assetId,
    required String assetType,
    required String karat,
    required double weightG,
    required double purchasePrice,
    required String purchaseDate,
    int? companyId,
    String? invoiceLocalPath,
    bool clearInvoice = false,
  }) async {
    if (kIsWeb) {
      final body = <String, dynamic>{
        'asset_type': assetType,
        'karat': karat,
        'weight_g': weightG,
        'purchase_price': purchasePrice,
        'purchase_date': purchaseDate,
        'company_id': companyId,
      };
      if (clearInvoice) {
        body['invoice_local_path'] = null;
      } else if (invoiceLocalPath != null) {
        body['invoice_local_path'] = invoiceLocalPath;
      }
      return (await _httpPut('/api/assets/$assetId', body))
          as Map<String, dynamic>;
    }
    final db = await _db;
    final map = <String, Object?>{
      'asset_type': assetType,
      'karat': karat,
      'company_id': companyId,
      'weight_g': weightG,
      'purchase_price': purchasePrice,
      'purchase_date': purchaseDate,
    };
    if (clearInvoice) {
      map['invoice_local_path'] = null;
    } else if (invoiceLocalPath != null) {
      map['invoice_local_path'] = invoiceLocalPath;
    }
    await db.update('Assets', map, where: 'id = ?', whereArgs: [assetId]);
    return _row(
        (await db.query('Assets', where: 'id = ?', whereArgs: [assetId]))
            .first);
  }

  Future<void> deleteAsset(int assetId) async {
    if (kIsWeb) {
      await _httpDelete('/api/assets/$assetId');
      return;
    }
    final db = await _db;
    await db.delete('Assets', where: 'id = ?', whereArgs: [assetId]);
  }

  // ════════════════════════════════════════════════════════════
  //  Summary & Zakat
  // ════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getMemberSummary(int memberId) async {
    if (kIsWeb)
      return (await _httpGet('/api/members/$memberId/assets-summary'))
          as Map<String, dynamic>;
    final assets = await getMemberAssets(memberId);
    final priceData = await getCurrentPrices();
    final prices = priceData['prices'] as Map<String, dynamic>;
    final summary =
        _buildAssetSummary(assets.cast<Map<String, dynamic>>(), prices);
    return {
      'member_id': memberId,
      'summary': summary,
      'assets_count': assets.length
    };
  }

  Future<Map<String, dynamic>> getMemberZakat(int memberId) async {
    if (kIsWeb)
      return (await _httpGet('/api/members/$memberId/zakat'))
          as Map<String, dynamic>;
    final assets = await getMemberAssets(memberId);
    final priceData = await getCurrentPrices();
    final prices = priceData['prices'] as Map<String, dynamic>;
    final summary =
        _buildAssetSummary(assets.cast<Map<String, dynamic>>(), prices);
    final zakat = _calculateZakat(
      totalValue: (summary['current_value'] as num).toDouble(),
      total24kWeight:
          (summary['total_weight_24k_equivalent'] as num).toDouble(),
    );
    return {
      'member_id': memberId,
      'total_value': summary['current_value'],
      'total_weight_24k_equivalent': summary['total_weight_24k_equivalent'],
      'zakat': zakat,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  Savings
  // ════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getSavings(int memberId) async {
    if (kIsWeb)
      return (await _httpGet('/api/members/$memberId/savings'))
          as Map<String, dynamic>;
    final db = await _db;
    final rows = _rows(await db.query('Savings',
        where: 'member_id = ?', whereArgs: [memberId], orderBy: 'id DESC'));
    final total = rows.fold<double>(
        0, (sum, r) => sum + ((r['amount'] as num?) ?? 0).toDouble());
    return {'entries': rows, 'total_saved': total};
  }

  Future<Map<String, dynamic>> addSaving(int memberId, double amount,
      {String? targetType, String? targetKarat}) async {
    if (kIsWeb) {
      return (await _httpPost('/api/members/$memberId/savings', {
        'amount': amount,
        'currency': 'EGP',
        if (targetType != null) 'target_type': targetType,
        if (targetKarat != null) 'target_karat': targetKarat,
      })) as Map<String, dynamic>;
    }
    final db = await _db;
    final id = await db.insert('Savings', {
      'member_id': memberId,
      'amount': amount,
      'currency': 'EGP',
      'target_type': targetType,
      'target_karat': targetKarat,
      'created_at': DateTime.now().toIso8601String(),
    });
    return _row(
        (await db.query('Savings', where: 'id = ?', whereArgs: [id])).first);
  }

  Future<void> updateSaving(int savingId, double amount) async {
    if (amount <= 0) throw Exception('Amount must be positive.');
    if (kIsWeb) {
      await _httpPut('/api/savings/$savingId', {'amount': amount});
      return;
    }
    final db = await _db;
    final check = await db.rawQuery(
      'SELECT s.id FROM Savings s INNER JOIN FamilyMembers m ON m.id = s.member_id WHERE s.id = ? AND m.user_id = ?',
      [savingId, _userId],
    );
    if (check.isEmpty) throw Exception('Saving not found.');
    await db.update('Savings', {'amount': amount},
        where: 'id = ?', whereArgs: [savingId]);
  }

  Future<void> deleteSaving(int savingId) async {
    if (kIsWeb) {
      await _httpDelete('/api/savings/$savingId');
      return;
    }
    final db = await _db;
    final check = await db.rawQuery(
      'SELECT s.id FROM Savings s INNER JOIN FamilyMembers m ON m.id = s.member_id WHERE s.id = ? AND m.user_id = ?',
      [savingId, _userId],
    );
    if (check.isEmpty) throw Exception('Saving not found.');
    await db.delete('Savings', where: 'id = ?', whereArgs: [savingId]);
  }

  /// Full JSON snapshot for backup (web: HTTP aggregate; same shape as mobile export).
  Future<Map<String, dynamic>> buildBackupJsonSnapshot() async {
    if (!kIsWeb) {
      throw StateError('Use BackupService export from SQLite on mobile.');
    }
    final members = (await getMembers()).cast<Map<String, dynamic>>();
    final allAssets = <Map<String, dynamic>>[];
    final allSavings = <Map<String, dynamic>>[];
    final allGoals = <Map<String, dynamic>>[];
    for (final m in members) {
      final mid = m['id'] as int;
      allAssets
          .addAll((await getMemberAssets(mid)).cast<Map<String, dynamic>>());
      final sv = await getSavings(mid);
      allSavings.addAll(
          (sv['entries'] as List<dynamic>).cast<Map<String, dynamic>>());
      allGoals.addAll((await getGoals(mid)).cast<Map<String, dynamic>>());
    }
    final companiesRaw = (await getCompanies()).cast<Map<String, dynamic>>();
    final companies =
        companiesRaw.where((c) => c['type']?.toString() != 'seeded').toList();
    Map<String, dynamic>? settingsRow;
    try {
      final me = await _httpGet('/api/me') as Map<String, dynamic>;
      final s = me['settings'];
      if (s != null && s is Map) {
        settingsRow = Map<String, dynamic>.from(s);
      }
    } catch (_) {}
    final settings =
        settingsRow != null ? [settingsRow] : <Map<String, dynamic>>[];
    return {
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'user_id': _userId,
      'members': members,
      'assets': allAssets,
      'savings': allSavings,
      'goals': allGoals,
      'companies': companies,
      'settings': settings,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  Goals
  // ════════════════════════════════════════════════════════════

  Future<List<dynamic>> getGoals(int memberId) async {
    if (kIsWeb)
      return (await _httpGet('/api/members/$memberId/goals')) as List<dynamic>;
    final db = await _db;
    return _rows(await db.query('PurchaseGoals',
        where: 'member_id = ?', whereArgs: [memberId], orderBy: 'id DESC'));
  }

  Future<Map<String, dynamic>> createGoal({
    required int memberId,
    required String karat,
    required double targetWeightG,
    required double savedAmount,
    int? companyId,
  }) async {
    if (kIsWeb) {
      return (await _httpPost('/api/goals/calculate', {
        'member_id': memberId,
        'karat': karat,
        'target_weight_g': targetWeightG,
        'saved_amount': savedAmount,
        'company_id': companyId,
      })) as Map<String, dynamic>;
    }
    final priceData = await getCurrentPrices();
    final prices = priceData['prices'] as Map<String, dynamic>;
    final calc = _calculateGoal(
        targetWeightG: targetWeightG,
        karat: karat,
        savedAmount: savedAmount,
        priceMap: prices);
    final db = await _db;
    await db.insert('PurchaseGoals', {
      'member_id': memberId,
      'company_id': companyId,
      'karat': karat,
      'target_weight_g': targetWeightG,
      'target_price': calc['target_price'],
      'saved_amount': calc['saved_amount'],
      'remaining_amount': calc['remaining_amount'],
      'created_at': DateTime.now().toIso8601String(),
    });
    return calc;
  }

  Future<Map<String, dynamic>> updateGoalSaved(
      {required int goalId, required double savedAmount}) async {
    if (kIsWeb)
      return (await _httpPut(
              '/api/goals/$goalId/saved', {'saved_amount': savedAmount}))
          as Map<String, dynamic>;
    final db = await _db;
    final goals = _rows(
        await db.query('PurchaseGoals', where: 'id = ?', whereArgs: [goalId]));
    if (goals.isEmpty) throw Exception('Goal not found');
    final goal = goals.first;
    final priceData = await getCurrentPrices();
    final prices = priceData['prices'] as Map<String, dynamic>;
    final calc = _calculateGoal(
      targetWeightG: (goal['target_weight_g'] as num).toDouble(),
      karat: goal['karat'] as String,
      savedAmount: savedAmount,
      priceMap: prices,
    );
    await db.update(
        'PurchaseGoals',
        {
          'saved_amount': calc['saved_amount'],
          'target_price': calc['target_price'],
          'remaining_amount': calc['remaining_amount'],
        },
        where: 'id = ?',
        whereArgs: [goalId]);
    return _row(
        (await db.query('PurchaseGoals', where: 'id = ?', whereArgs: [goalId]))
            .first);
  }

  Future<Map<String, dynamic>> updateGoal({
    required int goalId,
    required String karat,
    required double targetWeightG,
    required double savedAmount,
    int? companyId,
  }) async {
    if (kIsWeb) {
      return (await _httpPut('/api/goals/$goalId/saved', {
        'karat': karat,
        'target_weight_g': targetWeightG,
        'saved_amount': savedAmount,
        'company_id': companyId,
      })) as Map<String, dynamic>;
    }
    final priceData = await getCurrentPrices();
    final prices = priceData['prices'] as Map<String, dynamic>;
    final calc = _calculateGoal(
        targetWeightG: targetWeightG,
        karat: karat,
        savedAmount: savedAmount,
        priceMap: prices);
    final db = await _db;
    await db.update(
        'PurchaseGoals',
        {
          'karat': karat,
          'target_weight_g': targetWeightG,
          'target_price': calc['target_price'],
          'saved_amount': calc['saved_amount'],
          'remaining_amount': calc['remaining_amount'],
          'company_id': companyId,
        },
        where: 'id = ?',
        whereArgs: [goalId]);
    return _row(
        (await db.query('PurchaseGoals', where: 'id = ?', whereArgs: [goalId]))
            .first);
  }

  Future<void> deleteGoal(int goalId) async {
    if (kIsWeb) {
      await _httpDelete('/api/goals/$goalId');
      return;
    }
    final db = await _db;
    await db.delete('PurchaseGoals', where: 'id = ?', whereArgs: [goalId]);
  }

  // ════════════════════════════════════════════════════════════
  //  Companies
  // ════════════════════════════════════════════════════════════

  Future<List<dynamic>> getCompanies() async {
    if (kIsWeb) return (await _httpGet('/api/companies')) as List<dynamic>;
    final db = await _db;
    return _rows(await db.query('Companies', orderBy: 'name ASC'));
  }

  Future<Map<String, dynamic>> addCompany(String name) async {
    if (kIsWeb)
      return (await _httpPost('/api/companies', {'name': name}))
          as Map<String, dynamic>;
    final db = await _db;
    final id = await db.insert('Companies', {
      'name': name,
      'type': 'custom',
      'created_at': DateTime.now().toIso8601String()
    });
    return _row(
        (await db.query('Companies', where: 'id = ?', whereArgs: [id])).first);
  }

  // ════════════════════════════════════════════════════════════
  //  Settings
  // ════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getSettings() async {
    if (kIsWeb) return null;
    final db = await _db;
    final rows = await db
        .query('UserSettings', where: 'user_id = ?', whereArgs: [_userId]);
    if (rows.isEmpty) return null;
    return _row(rows.first);
  }

  Future<Map<String, dynamic>> updateSettings({
    required String locale,
    required String theme,
    required int notificationIntervalHours,
  }) async {
    if (kIsWeb) {
      return (await _httpPut('/api/me/settings', {
        'locale': locale,
        'theme': theme,
        'notification_interval_hours': notificationIntervalHours,
      })) as Map<String, dynamic>;
    }
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final existing = await db
        .query('UserSettings', where: 'user_id = ?', whereArgs: [_userId]);
    if (existing.isEmpty) {
      await db.insert('UserSettings', {
        'user_id': _userId,
        'locale': locale,
        'theme': theme,
        'notification_interval_hours': notificationIntervalHours,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
          'UserSettings',
          {
            'locale': locale,
            'theme': theme,
            'notification_interval_hours': notificationIntervalHours,
            'updated_at': now,
          },
          where: 'user_id = ?',
          whereArgs: [_userId]);
    }
    return _row((await db
            .query('UserSettings', where: 'user_id = ?', whereArgs: [_userId]))
        .first);
  }

  // ════════════════════════════════════════════════════════════
  //  Devices (FCM push registration) — always HTTP, since the push
  //  backend has no offline equivalent. Methods return null on failure
  //  so callers can degrade gracefully without exceptions bubbling up
  //  to the UI when the backend is unreachable.
  // ════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> registerDevice({
    required String deviceId,
    required String platform,
    required String fcmToken,
    String locale = 'en',
    int? buildNumber,
  }) async {
    try {
      final body = await _httpPost('/api/devices', {
        'device_id': deviceId,
        'platform': platform,
        'fcm_token': fcmToken,
        'locale': locale,
        if (buildNumber != null) 'build_number': buildNumber,
      });
      return Map<String, dynamic>.from(body as Map);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateDevice({
    required String deviceId,
    String? fcmToken,
    String? locale,
    bool? summariesEnabled,
    int? buildNumber,
  }) async {
    try {
      final body = await _httpPut('/api/devices/$deviceId', {
        if (fcmToken != null) 'fcm_token': fcmToken,
        if (locale != null) 'locale': locale,
        if (summariesEnabled != null) 'summaries_enabled': summariesEnabled,
        if (buildNumber != null) 'build_number': buildNumber,
      });
      return Map<String, dynamic>.from(body as Map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> removeDevice(String deviceId) async {
    try {
      await _httpDelete('/api/devices/$deviceId');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> sendTestPush(String deviceId) async {
    try {
      final body = await _httpPost('/api/devices/$deviceId/test', {});
      return Map<String, dynamic>.from(body as Map);
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════
  //  Default Member
  // ════════════════════════════════════════════════════════════

  int? _webDefaultMemberId;

  Future<int?> getDefaultMemberId() async {
    if (kIsWeb) return _webDefaultMemberId;
    final db = await _db;
    final rows = await db
        .query('UserSettings', where: 'user_id = ?', whereArgs: [_userId]);
    if (rows.isEmpty) return null;
    return rows.first['default_member_id'] as int?;
  }

  Future<void> setDefaultMemberId(int? memberId) async {
    _webDefaultMemberId = memberId;
    if (kIsWeb) return;
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final existing = await db
        .query('UserSettings', where: 'user_id = ?', whereArgs: [_userId]);
    if (existing.isEmpty) {
      await db.insert('UserSettings', {
        'user_id': _userId,
        'default_member_id': memberId,
        'locale': 'en',
        'theme': 'dark',
        'notification_interval_hours': 1,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
          'UserSettings', {'default_member_id': memberId, 'updated_at': now},
          where: 'user_id = ?', whereArgs: [_userId]);
    }
  }

  // ════════════════════════════════════════════════════════════
  //  Local calculation helpers (mobile only)
  // ════════════════════════════════════════════════════════════

  int _normalizeKarat(String karat) {
    final match = RegExp(r'\d+').firstMatch(karat);
    return match != null ? int.parse(match.group(0)!) : 24;
  }

  double _getBuyPrice(Map<String, dynamic> priceMap, String karat) {
    final key = '${_normalizeKarat(karat)}k';
    final row = priceMap[key] as Map<String, dynamic>?;
    return (row?['buy_price'] as num?)?.toDouble() ??
        (row?['sell_price'] as num?)?.toDouble() ??
        0;
  }

  Map<String, dynamic> _buildAssetSummary(
      List<Map<String, dynamic>> assets, Map<String, dynamic> priceMap) {
    double currentValue = 0, purchaseCost = 0, total24k = 0, total21k = 0;
    final byKarat = <String, double>{};
    for (final a in assets) {
      final karat = a['karat']?.toString() ?? '21k';
      final w = (a['weight_g'] as num?)?.toDouble() ?? 0;
      final pp = (a['purchase_price'] as num?)?.toDouble() ?? 0;
      final mp = _getBuyPrice(priceMap, karat);
      final k = _normalizeKarat(karat);
      currentValue += mp * w;
      purchaseCost += pp;
      total24k += w * k / 24;
      total21k += w * k / 21;
      byKarat[karat] = (byKarat[karat] ?? 0) + w;
    }
    return {
      'current_value': currentValue,
      'purchase_cost': purchaseCost,
      'profit_loss': currentValue - purchaseCost,
      'total_weight_by_karat': byKarat,
      'total_weight_24k_equivalent': total24k,
      'total_weight_21k_equivalent': total21k,
    };
  }

  Map<String, dynamic> _calculateGoal({
    required double targetWeightG,
    required String karat,
    required double savedAmount,
    required Map<String, dynamic> priceMap,
  }) {
    final pricePerGram = _getBuyPrice(priceMap, karat);
    final targetPrice = pricePerGram * targetWeightG;
    return {
      'target_price': targetPrice,
      'saved_amount': savedAmount,
      'remaining_amount': (targetPrice - savedAmount).clamp(0, double.infinity),
      'progress_percent':
          targetPrice > 0 ? (savedAmount / targetPrice * 100).clamp(0, 100) : 0,
    };
  }

  Map<String, dynamic> _calculateZakat(
      {required double totalValue, required double total24kWeight}) {
    const threshold = 85.0;
    final eligible = total24kWeight >= threshold;
    return {
      'threshold_weight_24k': threshold,
      'eligible': eligible,
      'zakat_due': eligible ? totalValue * 0.025 : 0.0
    };
  }
}
