import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';

class DriveService {
  // ID da pasta principal no seu Drive
  static const _folderId = '1YlKjI06LwhktjOwCnD0bIWsNaS0WIvIh';

  /// Cria cliente autenticado com a Service Account
  static Future<drive.DriveApi> _getDriveApi() async {
    // Lê o JSON da conta de serviço
    final serviceAccountJson =
        await rootBundle.loadString('assets/service_account.json');

    final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

    final client = await clientViaServiceAccount(
      credentials,
      [drive.DriveApi.driveFileScope],
    );

    return drive.DriveApi(client);
  }

  /// Faz upload de arquivo usando bytes (para Web)
  static Future<void> uploadBytesToUserFolder({
    required String userName,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final driveApi = await _getDriveApi();

    // Verifica ou cria pasta do usuário
    final userFolderId = await _getOrCreateUserFolder(driveApi, userName);

    final fileToUpload = drive.File()
      ..name = fileName
      ..parents = [userFolderId];

    final media = drive.Media(Stream.fromIterable([bytes]), bytes.length);

    await driveApi.files.create(fileToUpload, uploadMedia: media);
  }

  /// Faz upload de arquivo usando caminho (Mobile/Desktop)
  static Future<void> uploadFileToUserFolder({
    required String userName,
    required String filePath,
    required String fileName,
  }) async {
    final driveApi = await _getDriveApi();

    final userFolderId = await _getOrCreateUserFolder(driveApi, userName);

    final file = drive.File()
      ..name = fileName
      ..parents = [userFolderId];

    final media =
        drive.Media(File(filePath).openRead(), File(filePath).lengthSync());

    await driveApi.files.create(file, uploadMedia: media);
  }

  /// Retorna o ID da pasta do usuário, criando se não existir
  static Future<String> _getOrCreateUserFolder(
      drive.DriveApi driveApi, String userName) async {
    final folderList = await driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='$userName' and '$_folderId' in parents and trashed=false",
    );

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      return folderList.files!.first.id!;
    }

    // Cria a pasta se não existir
    final folder = drive.File()
      ..name = userName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [_folderId];

    final createdFolder = await driveApi.files.create(folder);
    return createdFolder.id!;
  }
}
