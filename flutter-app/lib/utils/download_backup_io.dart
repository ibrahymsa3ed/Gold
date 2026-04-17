import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadBackupFile(List<int> bytes, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);

  try {
    await Share.shareXFiles([XFile(file.path)], subject: 'InstaGold backup');
  } catch (_) {
    // Share sheet failed — file is saved in app documents directory
  }
}
