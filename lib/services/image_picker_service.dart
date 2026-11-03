import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Lets the person choose a photo and returns its path, or null if they
/// cancel. Phones use the gallery; Windows uses the standard "Open" dialog
/// (always on top, no extra packages).
Future<String?> pickImageFromComputer({String title = 'Choose a photo'}) async {
  if (kIsWeb) return null;
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
      );
      return file?.path;
    } catch (error) {
      debugPrint('Find Doctor photo picker: $error');
      return null;
    }
  }
  if (!Platform.isWindows) return null;
  final safeTitle = title.replaceAll("'", '');
  final script = "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
      "Add-Type -AssemblyName System.Windows.Forms; "
      r"$owner = New-Object System.Windows.Forms.Form -Property @{TopMost = $true; ShowInTaskbar = $false}; "
      r"$dialog = New-Object System.Windows.Forms.OpenFileDialog; "
      "\$dialog.Title = '$safeTitle'; "
      r"$dialog.Filter = 'Images|*.png;*.jpg;*.jpeg;*.gif;*.bmp;*.webp|All files|*.*'; "
      r"$dialog.InitialDirectory = [Environment]::GetFolderPath('MyPictures'); "
      r"if ($dialog.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) { [Console]::Out.Write($dialog.FileName) }; "
      r"$owner.Dispose()";
  try {
    final result = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-Command', script],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    final output = (result.stdout as String).trim();
    return output.isEmpty ? null : output;
  } catch (_) {
    return null;
  }
}
