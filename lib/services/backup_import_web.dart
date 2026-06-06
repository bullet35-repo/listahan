// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

Future<String?> pickBackupJson() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()
    ..accept = '.json,application/json'
    ..multiple = false;

  input.onChange.listen((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.onLoad.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(reader.result as String?);
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(reader.error ?? 'Read failed');
      }
    });
    reader.readAsText(file);
  });

  input.click();
  return completer.future;
}
