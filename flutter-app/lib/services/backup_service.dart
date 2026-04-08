import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/download_backup.dart';
import 'api_service.dart';
import 'database_helper.dart';
import 'google_drive_service.dart';

const _jsonName = 'instagold_backup.json';
const _zipName = 'instagold_backup.zip';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Map<String, dynamic>> exportData(String userId) async {
    final db = await _dbHelper.database;
    final members = _dbHelper.toDynamic(
      await db.query('FamilyMembers', where: 'user_id = ?', whereArgs: [userId]),
    );

    final allAssets = <Map<String, dynamic>>[];
    final allSavings = <Map<String, dynamic>>[];
    final allGoals = <Map<String, dynamic>>[];

    for (final m in members) {
      final memberId = m['id'] as int;
      final assets = _dbHelper.toDynamic(
        await db.query('Assets', where: 'member_id = ?', whereArgs: [memberId]),
      );
      final savings = _dbHelper.toDynamic(
        await db.query('Savings', where: 'member_id = ?', whereArgs: [memberId]),
      );
      final goals = _dbHelper.toDynamic(
        await db.query('PurchaseGoals', where: 'member_id = ?', whereArgs: [memberId]),
      );
      allAssets.addAll(assets);
      allSavings.addAll(savings);
      allGoals.addAll(goals);
    }

    final companies = _dbHelper.toDynamic(
      await db.query('Companies', where: "type != 'seeded'"),
    );

    final settings = _dbHelper.toDynamic(
      await db.query('UserSettings', where: 'user_id = ?', whereArgs: [userId]),
    );

    return {
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'user_id': userId,
      'members': members,
      'assets': allAssets,
      'savings': allSavings,
      'goals': allGoals,
      'companies': companies,
      'settings': settings,
    };
  }

  /// Builds a zip (JSON + invoice files) and shares / downloads it.
  /// When [autoUploadToDrive] is true, also uploads the zip to Google Drive.
  Future<void> exportBackupZip(
    ApiService apiService,
    String userId, {
    bool autoUploadToDrive = false,
  }) async {
    Map<String, dynamic> data;
    if (kIsWeb) {
      data = await apiService.buildBackupJsonSnapshot();
    } else {
      data = await exportData(userId);
    }
    final zipBytes = await _buildZipBytes(data);
    await downloadBackupFile(zipBytes, _zipName);

    if (autoUploadToDrive && !kIsWeb) {
      await uploadToDrive(zipBytes);
    }
  }

  /// Uploads backup zip to Google Drive without local save dialog.
  Future<String?> uploadToDrive(Uint8List? zipBytes, {ApiService? apiService, String? userId}) async {
    Uint8List bytes;
    if (zipBytes != null) {
      bytes = zipBytes;
    } else if (apiService != null && userId != null) {
      Map<String, dynamic> data;
      if (kIsWeb) {
        data = await apiService.buildBackupJsonSnapshot();
      } else {
        data = await exportData(userId!);
      }
      bytes = await _buildZipBytes(data);
    } else {
      return null;
    }

    final driveService = GoogleDriveService();
    return driveService.uploadBackup(bytes, _zipName);
  }

  Future<Uint8List> _buildZipBytes(Map<String, dynamic> data) async {
    final archive = Archive();
    final dataCopy = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    final assets = ((dataCopy['assets'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (!kIsWeb) {
      for (final a in assets) {
        final path = a['invoice_local_path'] as String?;
        if (path != null && path.isNotEmpty) {
          final f = File(path);
          if (await f.exists()) {
            final id = a['id'];
            final arcName = 'invoices/a${id}_${p.basename(path)}';
            final bytes = await f.readAsBytes();
            archive.addFile(ArchiveFile(arcName, bytes.length, bytes));
            a.remove('invoice_local_path');
            a['invoice_archive_path'] = arcName;
          }
        }
      }
    }
    dataCopy['assets'] = assets;

    final jsonStr = const JsonEncoder.withIndent('  ').convert(dataCopy);
    final jsonBytes = utf8.encode(jsonStr);
    archive.addFile(ArchiveFile(_jsonName, jsonBytes.length, jsonBytes));
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw Exception('Failed to create zip archive.');
    return Uint8List.fromList(encoded);
  }

  Future<void> restoreFromPickedBytes(Uint8List bytes, String userId) async {
    if (kIsWeb) {
      throw Exception('Restore from file is only available in the mobile app.');
    }
    if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      await _restoreFromZip(bytes, userId);
    } else {
      final jsonStr = utf8.decode(bytes);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      await _importData(data, userId);
    }
  }

  Future<void> _restoreFromZip(Uint8List bytes, String userId) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? jsonFile;
    final base = await getApplicationDocumentsDirectory();
    for (final file in archive.files) {
      if (file.name.endsWith('/')) continue;
      if (file.name == _jsonName) {
        jsonFile = file;
        continue;
      }
      if (file.name.startsWith('invoices/')) {
        final out = File(p.join(base.path, file.name));
        await out.parent.create(recursive: true);
        final content = file.content;
        if (content is List<int>) {
          await out.writeAsBytes(content);
        } else if (content is Uint8List) {
          await out.writeAsBytes(content);
        }
      }
    }
    if (jsonFile == null) throw Exception('Invalid backup: missing $_jsonName');
    final raw = jsonFile.content;
    final jsonBytes = raw is Uint8List ? raw : Uint8List.fromList(raw as List<int>);
    final data = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;

    final assets = (data['assets'] as List?) ?? [];
    final fixed = <Map<String, dynamic>>[];
    for (final a in assets) {
      final m = Map<String, dynamic>.from(a as Map);
      final arc = m['invoice_archive_path'] as String?;
      if (arc != null) {
        m['invoice_local_path'] = p.join(base.path, arc);
        m.remove('invoice_archive_path');
      }
      fixed.add(m);
    }
    data['assets'] = fixed;

    await _importData(data, userId);
  }

  Future<void> _importData(Map<String, dynamic> data, String userId) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final existingMemberIds = (await txn.query('FamilyMembers',
              columns: ['id'], where: 'user_id = ?', whereArgs: [userId]))
          .map((r) => r['id'] as int)
          .toList();

      for (final mid in existingMemberIds) {
        await txn.delete('Assets', where: 'member_id = ?', whereArgs: [mid]);
        await txn.delete('Savings', where: 'member_id = ?', whereArgs: [mid]);
        await txn.delete('PurchaseGoals', where: 'member_id = ?', whereArgs: [mid]);
      }
      await txn.delete('FamilyMembers', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('Companies', where: "type = 'custom'");
      await txn.delete('UserSettings', where: 'user_id = ?', whereArgs: [userId]);

      final members = (data['members'] as List?) ?? [];
      final oldToNewMemberId = <int, int>{};

      for (final m in members) {
        final map = Map<String, dynamic>.from(m as Map);
        final oldId = map.remove('id') as int;
        map['user_id'] = userId;
        final newId = await txn.insert('FamilyMembers', map);
        oldToNewMemberId[oldId] = newId;
      }

      for (final a in ((data['assets'] as List?) ?? [])) {
        final map = Map<String, dynamic>.from(a as Map);
        map.remove('id');
        final oldMemberId = map['member_id'] as int;
        map['member_id'] = oldToNewMemberId[oldMemberId] ?? oldMemberId;
        map.remove('invoice_archive_path');
        await txn.insert('Assets', map);
      }

      for (final s in ((data['savings'] as List?) ?? [])) {
        final map = Map<String, dynamic>.from(s as Map);
        map.remove('id');
        final oldMemberId = map['member_id'] as int;
        map['member_id'] = oldToNewMemberId[oldMemberId] ?? oldMemberId;
        await txn.insert('Savings', map);
      }

      for (final g in ((data['goals'] as List?) ?? [])) {
        final map = Map<String, dynamic>.from(g as Map);
        map.remove('id');
        final oldMemberId = map['member_id'] as int;
        map['member_id'] = oldToNewMemberId[oldMemberId] ?? oldMemberId;
        await txn.insert('PurchaseGoals', map);
      }

      for (final c in ((data['companies'] as List?) ?? [])) {
        final map = Map<String, dynamic>.from(c as Map);
        map.remove('id');
        await txn.insert('Companies', map);
      }

      for (final s in ((data['settings'] as List?) ?? [])) {
        final map = Map<String, dynamic>.from(s as Map);
        map.remove('id');
        map['user_id'] = userId;
        await txn.insert('UserSettings', map);
      }
    });
  }
}