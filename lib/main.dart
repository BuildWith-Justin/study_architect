import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // V2: load Supabase credentials from .env and start the client.
  // Wrapped in try/catch so a missing .env or a Supabase problem never
  // stops the local-first app from launching.
  try {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    debugPrint('Supabase initialized OK');
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }

  // Safe no-op on Web — see notification_service.dart for why.
  await NotificationService.instance.init();
  runApp(const StudyArchitectApp());
}