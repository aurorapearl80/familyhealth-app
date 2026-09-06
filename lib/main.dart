import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

import 'navigation.dart';
import 'screens/auth/splash_screen.dart';
import 'services/ble_scan_service.dart';
import 'services/ble_summary_service.dart';
import 'services/chat_service.dart';
import 'services/connectivity_service.dart';
import 'services/location_service.dart';
import 'services/native_call_bridge.dart';
import 'services/onesignal_service.dart';
import 'services/patient_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Use Hybrid Composition so Google Maps embeds at the Android OS layer
  // instead of going through Flutter's SurfaceProducer capture pipeline,
  // which abandons its ImageReader on background/foreground cycles.
  final mapsImpl = GoogleMapsFlutterPlatform.instance;
  if (mapsImpl is GoogleMapsFlutterAndroid) {
    mapsImpl.useAndroidViewSurface = true;
    await mapsImpl.initializeWithRenderer(AndroidMapRenderer.latest);
  }

  // ── OneSignal: initialize early (before runApp) ──────────────────────────
  OneSignalService.initialize();
  OneSignalService.registerCallListeners();
  NativeCallBridge.registerOpenVideoCallHandler();

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
        ChangeNotifierProvider(create: (_) => ChatService()),
      ],
      child: Builder(
        builder: (context) {
          // Refresh account vitals summaries as soon as a BP Watch history sync
          // concludes, so screens don't need a manual pull-to-refresh to see it.
          context.read<BleScanService>().onSyncCompleted =
              () => context.read<BleSummaryService>().fetch();
          return MaterialApp(
            title: 'Family Watch Today',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.light,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
