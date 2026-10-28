import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Saving and opening backup files through the system file picker, behind an
/// interface so tests can stand in for it.
abstract interface class BackupFiles {
  /// Asks where to save [bytes]; returns false if the user cancelled.
  Future<bool> save(String fileName, Uint8List bytes);

  /// Asks for a file to open; returns null if the user cancelled.
  Future<Uint8List?> open();
}

/// Uses Android's own "Save to" and "Open" screens, which also reach Google
/// Drive and other installed storage apps.
class SystemBackupFiles implements BackupFiles {
  const SystemBackupFiles();

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Save backup',
    );
    return uri != null;
  }

  @override
  Future<Uint8List?> open() async {
    // Any type: some file managers don't tag .json files as JSON, which would
    // grey them out under a JSON-only filter.
    final file = await FilePicker.pickFile(dialogTitle: 'Choose a backup file');
    return file?.readAsBytes();
  }
}
