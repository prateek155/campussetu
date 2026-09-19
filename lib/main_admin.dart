import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_admin.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0F1A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: CampusSetuAdminApp()));
}
