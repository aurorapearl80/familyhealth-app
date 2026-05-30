import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

import 'screens/auth/splash_screen.dart';
import 'services/ble_scan_service.dart';
import 'services/ble_summary_service.dart';
import 'services/connectivity_service.dart';
import 'services/location_service.dart';
import 'services/onesignal_service.dart';
import 'services/patient_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ── OneSignal: initialize early (before runApp) ──────────────────────────
  OneSignalService.initialize();

  // ── WorkManager: register the background GPS callback ───────────────────
  await Workmanager().initialize(
    locationCallbackDispatcher, // top-level fn in location_service.dart
    isInDebugMode: false,
  );

  runApp(const FamilyHealthApp());
}

class FamilyHealthApp extends StatelessWidget {
  const FamilyHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleScanService()..initialize()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => BleSummaryService()),
        ChangeNotifierProvider(create: (_) => PatientService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: MaterialApp(
        title: 'Family Watch Today',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
