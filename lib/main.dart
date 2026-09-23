import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app/app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Plain sqflite only ships a native database engine for Android/iOS.
  // On Windows and Linux desktop there is no such engine bundled, so
  // sqflite_common_ffi's databaseFactory must be installed explicitly
  // before DatabaseService (or anything else) opens a database —
  // otherwise every DB call throws "databaseFactory not initialized."
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Safe no-op on Web — see notification_service.dart for why.
  await NotificationService.instance.init();
  runApp(const StudyArchitectApp());
}