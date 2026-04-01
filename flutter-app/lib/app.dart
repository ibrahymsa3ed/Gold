import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_themes.dart';
import 'theme/ui_design_variant.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/notifications_service.dart';

class GoldFamilyApp extends StatefulWidget {
  const GoldFamilyApp({super.key});

  @override
  State<GoldFamilyApp> createState() => _GoldFamilyAppState();
}

class _GoldFamilyAppState extends State<GoldFamilyApp> {
  final AuthService _authService = AuthService();
  final NotificationsService _notificationsService = NotificationsService();

  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('en');
  bool _devBypass = false;

  @override
  void initState() {
    super.initState();
    _notificationsService.init();
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
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!snapshot.hasData && !_devBypass) {
              return LoginScreen(
                authService: _authService,
                onDevBypass: () => setState(() => _devBypass = true),
              );
            }
            return DashboardScreen(
              authService: _authService,
              apiService: _devBypass ? ApiService.devBypass() : ApiService(_authService),
              locale: _locale,
              themeMode: _themeMode,
              notificationsService: _notificationsService,
              onLocaleChanged: (locale) => setState(() => _locale = locale),
              onThemeChanged: (isDark) =>
                  setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light),
            );
          },
        ),
      ),
    );
  }
}
