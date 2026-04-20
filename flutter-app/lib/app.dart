import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_themes.dart';
import 'theme/ui_design_variant.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/notifications_service.dart';
import 'services/push_notifications_service.dart';

class GoldFamilyApp extends StatefulWidget {
  const GoldFamilyApp({super.key});

  @override
  State<GoldFamilyApp> createState() => _GoldFamilyAppState();
}

class _GoldFamilyAppState extends State<GoldFamilyApp> {
  final AuthService _authService = AuthService();
  final NotificationsService _notificationsService = NotificationsService();
  late final PushNotificationsService _pushService =
      PushNotificationsService(_notificationsService);
  bool _pushInitStarted = false;

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('en');
  bool _guestMode = false;
  bool _settingsLoaded = false;

  static const _kThemeKey = 'instagold_theme';
  static const _kLocaleKey = 'instagold_locale';
  static const _kGuestKey = 'instagold_guest';

  @override
  void initState() {
    super.initState();
    _notificationsService.init();
    _initApp();
  }

  Future<void> _initApp() async {
    await _authService.restoreSession();

    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString(_kThemeKey);
      final locale = prefs.getString(_kLocaleKey);
      final guest = prefs.getBool(_kGuestKey) ?? false;
      if (mounted) {
        setState(() {
          _themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
          _locale = locale == 'ar' ? const Locale('ar') : const Locale('en');
          _guestMode = guest;
          _settingsLoaded = true;
        });
      }
      // Seed the App Group locale so the iOS widget renders in the correct
      // language on its very first frame after a fresh install / cold launch.
      if (!kIsWeb) {
        HomeWidget.saveWidgetData<String>('locale', _locale.languageCode);
      }
    } catch (_) {
      if (mounted) setState(() => _settingsLoaded = true);
    }
  }

  void _handleThemeChanged(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kThemeKey, isDark ? 'dark' : 'light');
    });
  }

  void _handleLocaleChanged(Locale locale) {
    setState(() => _locale = locale);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kLocaleKey, locale.languageCode);
    });
    // Push the new locale into the App Group so the iOS widget can render
    // karat labels in the correct language on its next refresh.
    if (!kIsWeb) {
      HomeWidget.saveWidgetData<String>('locale', locale.languageCode);
      HomeWidget.updateWidget(
        name: 'InstaGoldWidgetProvider',
        iOSName: 'InstaGoldWidget',
        qualifiedAndroidName:
            'com.ibrahym.instagold.InstaGoldWidgetProvider',
      );
    }
    // Tell the backend so summary push bodies switch language for this device.
    if (_pushInitStarted) {
      final api = _guestMode ? ApiService.devBypass() : ApiService(_authService);
      _pushService.syncLocale(api, locale.languageCode);
    }
  }

  // Lazily initialise the FCM push service the first time the dashboard
  // builds with a known auth state. Done here (vs main.dart) so the auth
  // bearer token is available for /api/devices, and so we know the locale.
  void _ensurePushInitialized() {
    if (_pushInitStarted) return;
    _pushInitStarted = true;
    final api = _guestMode ? ApiService.devBypass() : ApiService(_authService);
    _pushService.initialize(
      apiService: api,
      localeCode: _locale.languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InstaGold',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: _themeMode,
      theme: instaGoldLightTheme(kUiDesignVariant),
      darkTheme: instaGoldDarkTheme(kUiDesignVariant),
      home: SelectionArea(
        child: StreamBuilder<User?>(
          stream: _authService.authState,
          initialData: _authService.currentUser,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || !_settingsLoaded) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!snapshot.hasData && !_guestMode) {
              return LoginScreen(
                authService: _authService,
                onGuestLogin: () {
                  setState(() => _guestMode = true);
                  SharedPreferences.getInstance().then((p) => p.setBool(_kGuestKey, true));
                },
              );
            }
            // Defer push init until first dashboard build so auth + locale
            // are both settled. Schedule it post-frame to avoid jank.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _ensurePushInitialized();
            });
            return DashboardScreen(
              authService: _authService,
              apiService: _guestMode ? ApiService.devBypass() : ApiService(_authService),
              locale: _locale,
              themeMode: _themeMode,
              notificationsService: _notificationsService,
              pushNotificationsService: _pushService,
              onLocaleChanged: _handleLocaleChanged,
              onThemeChanged: _handleThemeChanged,
              onLogout: () {
                setState(() => _guestMode = false);
                SharedPreferences.getInstance().then((p) => p.setBool(_kGuestKey, false));
              },
            );
          },
        ),
      ),
    );
  }
}
