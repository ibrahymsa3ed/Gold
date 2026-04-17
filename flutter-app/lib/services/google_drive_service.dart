import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

class DriveFolder {
  final String id;
  final String name;
  const DriveFolder(this.id, this.name);
}

class GoogleDriveService {
  static const _defaultFolderName = 'InstaGold Backups';
  static const _mimeFolder = 'application/vnd.google-apps.folder';

  final GoogleSignIn _googleSignIn = sharedGoogleSignIn;

  Future<drive.DriveApi?> _driveApi() async {
    var httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      // Session expired or app restarted — try restoring silently
      await _googleSignIn.signInSilently();
      httpClient = await _googleSignIn.authenticatedClient();
    }
    if (httpClient == null) return null;
    return drive.DriveApi(httpClient);
  }

  /// Lists folders inside [parentId] (defaults to root "My Drive").
  /// Returns null when the user isn't signed in.
  Future<List<DriveFolder>?> listFolders({String? parentId}) async {
    final api = await _driveApi();
    if (api == null) return null;

    final parent = parentId ?? 'root';
    final query =
        "'$parent' in parents and mimeType = '$_mimeFolder' and trashed = false";
    final result = await api.files.list(
      q: query,
      spaces: 'drive',
      orderBy: 'name',
      $fields: 'files(id, name)',
      pageSize: 100,
    );
    return (result.files ?? [])
        .where((f) => f.id != null && f.name != null)
        .map((f) => DriveFolder(f.id!, f.name!))
        .toList();
  }

  /// Creates a new folder in [parentId] and returns its metadata.
  Future<DriveFolder?> createFolder(String name, {String? parentId}) async {
    final api = await _driveApi();
    if (api == null) return null;

    final folder = drive.File()
      ..name = name
      ..mimeType = _mimeFolder
      ..parents = [parentId ?? 'root'];
    final created = await api.files.create(folder);
    if (created.id == null) return null;
    return DriveFolder(created.id!, name);
  }

  Future<String?> _getOrCreateDefaultFolder(drive.DriveApi api) async {
    final query =
        "name = '$_defaultFolderName' and mimeType = '$_mimeFolder' and trashed = false";
    final found = await api.files
        .list(q: query, spaces: 'drive', $fields: 'files(id)');
    if (found.files != null && found.files!.isNotEmpty) {
      return found.files!.first.id;
    }

    final folder = drive.File()
      ..name = _defaultFolderName
      ..mimeType = _mimeFolder;
    final created = await api.files.create(folder);
    return created.id;
  }

  /// Uploads [zipBytes] to Google Drive. When [folderId] is null it falls back
  /// to the auto-created "InstaGold Backups" folder.
  Future<String?> uploadBackup(
    Uint8List zipBytes,
    String fileName, {
    String? folderId,
  }) async {
    final api = await _driveApi();
    if (api == null) return null;

    final targetFolder =
        folderId ?? await _getOrCreateDefaultFolder(api);
    if (targetFolder == null) return null;

    final existingQuery =
        "name = '$fileName' and '$targetFolder' in parents and trashed = false";
    final existing = await api.files
        .list(q: existingQuery, spaces: 'drive', $fields: 'files(id)');
    if (existing.files != null && existing.files!.isNotEmpty) {
      for (final old in existing.files!) {
        if (old.id != null) await api.files.delete(old.id!);
      }
    }

    final driveFile = drive.File()
      ..name = fileName
      ..parents = [targetFolder];

    final media = drive.Media(
      Stream.value(zipBytes),
      zipBytes.length,
      contentType: 'application/zip',
    );

    final result = await api.files.create(driveFile, uploadMedia: media);
    return result.id;
  }
}
