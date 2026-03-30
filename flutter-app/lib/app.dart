import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'l10n.dart';
import 'screens/dashboard_screen.dart';
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

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _notificationsService.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gold Family App',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppStrings.supportedLocales,
      themeMode: _themeMode,
      theme: ThemeData(colorSchemeSeed: Colors.amber, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.amber, brightness: Brightness.dark),
      home: StreamBuilder<User?>(
        stream: _authService.authState,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return LoginScreen(authService: _authService);
          }
          return DashboardScreen(
            authService: _authService,
            apiService: ApiService(_authService),
            locale: _locale,
            themeMode: _themeMode,
            notificationsService: _notificationsService,
            onLocaleChanged: (locale) => setState(() => _locale = locale),
            onThemeChanged: (isDark) =>
                setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light),
          );
        },
      ),
    );
  }
}
