import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<void> downloadBackupFile(List<int> bytes, String filename) async {
  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save backup',
    fileName: filename,
    type: FileType.any,
  );

  if (savePath != null) {
    final file = File(savePath);
    await file.writeAsBytes(bytes);
    return;
  }

  // Fallback: save to app documents if the user cancelled the picker
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
}
