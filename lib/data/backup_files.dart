import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'carty_backup.dart';

class PickedBackupFile {
  const PickedBackupFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

abstract interface class BackupFiles {
  Future<PickedBackupFile?> pick();
  Future<bool> save(Uint8List bytes, String suggestedName);
}

class NativeBackupFiles implements BackupFiles {
  @override
  Future<PickedBackupFile?> pick() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a Carty backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;
    final length = await file.length();
    if (length != null && length > CartyBackup.maxBytes) {
      throw const FormatException('Backup exceeds 20 MB');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (bytes.length + chunk.length > CartyBackup.maxBytes) {
        throw const FormatException('Backup exceeds 20 MB');
      }
      bytes.add(chunk);
    }
    return PickedBackupFile(file.name, bytes.takeBytes());
  }

  @override
  Future<bool> save(Uint8List bytes, String suggestedName) async =>
      await FilePicker.saveFile(
        fileName: suggestedName,
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: 'Save your Carty backup',
      ) !=
      null;
}
