import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'constants/splash_branding.dart';
import 'app_scope.dart';
import 'services/ble_frame_device_transport.dart';
import 'services/device_transport.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';
import 'navigation/app_routes.dart';
import 'screens/app_entry_screen.dart';
import 'services/family_invite_deep_link.dart';
import 'services/mobile_auth_deep_link.dart';
import 'services/share_incoming_service.dart';
import 'services/app_diag_log.dart';
import 'services/app_release_guard.dart';
import 'services/google_photos_service.dart';
import 'services/icloud_photos_service.dart';
import 'services/fcm_service.dart';

final DeviceTransport _globalTransport = BleFrameDeviceTransport.instance;

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppReleaseGuard.init();
    final settings = AppSettings();
    await _guardStartup('app settings', settings.load);
    FlutterError.onError = (details) {
      AppDiagLog.verbose('[FlutterError] ${details.exceptionAsString()}');
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };
    await _guardStartup(
      'family invite deep links',
      FamilyInviteDeepLink.bootstrap,
    );
    await _guardStartup('mobile auth deep links', MobileAuthDeepLink.bootstrap);
    await _guardStartup(
      'google photos prefs',
      GooglePhotosService.instance.loadPrefs,
    );
    await _guardStartup(
      'icloud photos prefs',
      ICloudPhotosService.instance.loadPrefs,
    );
    await _guardStartup(
      'share incoming service',
      ShareIncomingService.instance.bootstrap,
    );
    await _guardStartup('splash branding', SplashBranding.preload);
    await _guardStartup('fcm', FcmService.instance.init);
    runApp(MyFrameApp(settings: settings));
  }, AppReleaseGuard.onUncaughtError);
}

Future<void> _guardStartup(String label, Future<void> Function() action) async {
  try {
    await action();
  } catch (e, st) {
    AppDiagLog.verbose('[startup] $label failed: $e');
    AppDiagLog.verbose('$st');
  }
}

class MyFrameApp extends StatelessWidget {
  const MyFrameApp({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      notifier: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return AppScope(
            transport: _globalTransport,
            child: MaterialApp(
              title: 'MyFrame',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(
                settings.accent,
                comfort: settings.comfortMode,
              ),
              darkTheme: AppTheme.dark(
                settings.accent,
                comfort: settings.comfortMode,
              ),
              themeMode: settings.themeMode,
              locale: settings.locale,
              builder: (context, child) {
                final c = child;
                if (c == null) return const SizedBox.shrink();
                final mq = MediaQuery.of(context);
                final app = AppSettingsScope.of(context);
                final systemFactor = mq.textScaler.scale(16) / 16.0;
                final comfortBoost = app.comfortMode ? 1.2 : 1.0;
                return MediaQuery(
                  data: mq.copyWith(
                    textScaler: TextScaler.linear(
                      systemFactor * comfortBoost,
                    ).clamp(minScaleFactor: 0.88, maxScaleFactor: 1.9),
                  ),
                  child: c,
                );
              },
              supportedLocales: const [
                Locale('en'),
                Locale('zh'),
                Locale('es'),
                Locale('fr'),
                Locale('de'),
                Locale('ja'),
              ],
              localeResolutionCallback: (locale, supported) {
                if (locale == null) return const Locale('en');
                for (final l in supported) {
                  if (l.languageCode == locale.languageCode) return l;
                }
                return const Locale('en');
              },
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const AppEntryScreen(),
              routes: AppRoutes.routes,
              onGenerateRoute: AppRoutes.onGenerateRoute,
            ),
          );
        },
      ),
    );
  }
}
