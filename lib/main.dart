import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/di/dependency_injection.dart';
import 'features/settings/settings_provider.dart';
import 'core/widgets/app_loading_screen.dart';
import 'core/services/version_check_service.dart';
import 'features/force_update/force_update_screen.dart';
import 'core/services/payment_notification_service.dart';

void main() async {
  // Aseguramos que los canales nativos estén listos
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Redirige todos los errores de Flutter a Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  runApp(const AppInitializer());
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  SharedPreferences? _prefs;
  bool _initialized = false;
  VersionCheckResult? _versionCheck;

  @override
  void initState() {
    super.initState();
    _startInitialization();
    PaymentNotificationService.init();
  }

  Future<void> _startInitialization() async {
    // 1. Cargamos SharedPreferences primero (es crítico para el resto)
    final prefs = await SharedPreferences.getInstance();

    // 2. Iniciamos locale, tiempo mínimo visual y check de versión en paralelo.
    // DB y VoiceService se inicializan vía sus providers (instancia única).
    final sysLocale = ui.PlatformDispatcher.instance.locale;
    final localeStr = sysLocale.countryCode != null && sysLocale.countryCode!.isNotEmpty
        ? '${sysLocale.languageCode}_${sysLocale.countryCode}'
        : sysLocale.languageCode;

    final results = await Future.wait([
      initializeDateFormatting(localeStr, null)
          .catchError((_) => initializeDateFormatting('en_US', null)),
      Future.delayed(const Duration(milliseconds: 1800)),
      VersionCheckService.check(),
    ]);

    if (mounted) {
      setState(() {
        _prefs = prefs;
        _versionCheck = results[2] as VersionCheckResult;
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const AppLoadingScreen();
    }

    // Si la versión es obsoleta, mostramos pantalla de actualización forzada
    final check = _versionCheck;
    if (check != null && check.needsUpdate) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: ForceUpdateScreen(
          packageName: check.packageName,
          currentVersion: check.currentVersion,
          minVersion: check.minVersion,
        ),
      );
    }

    // Inyectamos las dependencias ya calentadas
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs!),
      ],
      child: const MyApp(),
    );
  }
}

const _themeModeMap = {
  'light': ThemeMode.light,
  'dark': ThemeMode.dark,
  'system': ThemeMode.system,
};

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = _themeModeMap[settings.themeMode] ?? ThemeMode.system;

    return MaterialApp(
      title: 'MoneoVoice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const DashboardScreen(),
    );
  }
}
