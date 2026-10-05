import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'features/auth/auth_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';

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
    // Only flips to true when init fully succeeded. AuthGate reads this
    // so it never touches Supabase.instance when the client isn't ready.
    AuthService.isAvailable = true;
    debugPrint('Supabase initialized OK');

    // V2 Step 4: start local <-> cloud sync (does nothing until signed in).
    SyncService.instance.start();
  } catch (e) {
    AuthService.isAvailable = false;
    debugPrint('Supabase init failed: $e');
  }

  // Safe no-op on Web — see notification_service.dart for why.
  await NotificationService.instance.init();
  runApp(const StudyArchitectApp());
}
