import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initDatabase() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
