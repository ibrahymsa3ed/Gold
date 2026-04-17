import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> downloadBackupFile(List<int> bytes, String filename) async {
  final data = Uint8List.fromList(bytes);

  await FilePicker.platform.saveFile(
    dialogTitle: 'Save backup',
    fileName: filename,
    type: FileType.any,
    bytes: data,
  );
}
