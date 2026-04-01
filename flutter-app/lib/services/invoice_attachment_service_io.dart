import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class InvoiceAttachmentService {
  Future<String?> copyPickedToAppStorage(PlatformFile? picked) async {
    if (picked == null) return null;
    final path = picked.path;
    if (path == null || path.isEmpty) return null;
    final dir = await getApplicationDocumentsDirectory();
    final inv = Directory(p.join(dir.path, 'invoices'));
    if (!await inv.exists()) await inv.create(recursive: true);
    final name = p.basename(path);
    final dest = p.join(inv.path, '${DateTime.now().millisecondsSinceEpoch}_$name');
    await File(path).copy(dest);
    return dest;
  }

  Future<void> deleteFileIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
