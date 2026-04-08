import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

class GoogleDriveService {
  static const _folderName = 'InstaGold Backups';
  static const _mimeFolder = 'application/vnd.google-apps.folder';

  final GoogleSignIn _googleSignIn = sharedGoogleSignIn;

  Future<drive.DriveApi?> _driveApi() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return null;
    return drive.DriveApi(httpClient);
  }

  Future<String?> _getOrCreateFolder(drive.DriveApi api) async {
    final query = "name = '$_folderName' and mimeType = '$_mimeFolder' and trashed = false";
    final found = await api.files.list(q: query, spaces: 'drive', $fields: 'files(id)');
    if (found.files != null && found.files!.isNotEmpty) {
      return found.files!.first.id;
    }

    final folder = drive.File()
      ..name = _folderName
      ..mimeType = _mimeFolder;
    final created = await api.files.create(folder);
    return created.id;
  }

  /// Uploads [zipBytes] as a backup file to Google Drive under the
  /// "InstaGold Backups" folder. Returns the file ID on success.
  Future<String?> uploadBackup(Uint8List zipBytes, String fileName) async {
    final api = await _driveApi();
    if (api == null) return null;

    final folderId = await _getOrCreateFolder(api);
    if (folderId == null) return null;

    final existingQuery =
        "name = '$fileName' and '$folderId' in parents and trashed = false";
    final existing = await api.files.list(q: existingQuery, spaces: 'drive', $fields: 'files(id)');
    if (existing.files != null && existing.files!.isNotEmpty) {
      for (final old in existing.files!) {
        if (old.id != null) await api.files.delete(old.id!);
      }
    }

    final driveFile = drive.File()
      ..name = fileName
      ..parents = [folderId];

    final media = drive.Media(
      Stream.value(zipBytes),
      zipBytes.length,
      contentType: 'application/zip',
    );

    final result = await api.files.create(driveFile, uploadMedia: media);
    return result.id;
  }
}
