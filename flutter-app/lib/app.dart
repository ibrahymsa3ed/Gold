import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n.dart';
import 'screens/dashboard_screen.dart';
import 'screens/tutorial_screen.dart';
import 'theme/app_themes.dart';
import 'theme/ui_design_variant.dart';
import 'screens/login_screen.dart';
import 'services/analytics_service.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/notifications_service.dart';
import 'services/push_notifications_service.dart';
import 'services/update_service.dart';

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
  bool _tutorialSeen = true;

  bool _updateCheckDone = false;

  static const _kThemeKey = 'instagold_theme';
  static const _kLocaleKey = 'instagold_locale';
  static const _kGuestKey = 'instagold_guest';
  static const _kTutorialKey = 'instagold_tutorial_seen';
  static const _kLastWhatsNewBuild = 'instagold_last_whats_new_build';
  static const _kDismissedUpdateVersion = 'instagold_dismissed_update_version';

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
      final tutorialSeen = prefs.getBool(_kTutorialKey) ?? false;
      if (mounted) {
        setState(() {
          _themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
          _locale = locale == 'ar' ? const Locale('ar') : const Locale('en');
          _guestMode = guest;
          _tutorialSeen = tutorialSeen;
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
    AnalyticsService.instance.logThemeChanged(isDark ? 'dark' : 'light');
  }

  void _handleLocaleChanged(Locale locale) {
    setState(() => _locale = locale);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kLocaleKey, locale.languageCode);
    });
    AnalyticsService.instance.logLanguageChanged(locale.languageCode);
    // Push the new locale into the App Group so the iOS widget can render
    // karat labels in the correct language on its next refresh.
    if (!kIsWeb) {
      HomeWidget.saveWidgetData<String>('locale', locale.languageCode);
      HomeWidget.updateWidget(
        name: 'InstaGoldWidgetProvider',
        iOSName: 'InstaGoldWidget',
        qualifiedAndroidName: 'com.ibrahym.instagold.InstaGoldWidgetProvider',
      );
    }
    // Tell the backend so summary push bodies switch language for this device.
    if (_pushInitStarted) {
      final api =
          _guestMode ? ApiService.devBypass() : ApiService(_authService);
      _pushService.syncLocale(api, locale.languageCode);
    }
  }

  // Lazily initialise the FCM push service the first time the dashboard
  // builds with a known auth state. Done here (vs main.dart) so the auth
  // bearer token is available for /api/devices, and so we know the locale.
  void _ensurePushInitialized() {
    if (_pushInitStarted) return;
    _pushInitStarted = true;
    if (kDebugMode) {
      debugPrint(
        'InstaGold: _ensurePushInitialized '
        'guestMode=$_guestMode locale=${_locale.languageCode} '
        'api=${_guestMode ? 'devBypass' : 'authenticated'}',
      );
    }
    final api = _guestMode ? ApiService.devBypass() : ApiService(_authService);
    _pushService.initialize(
      apiService: api,
      localeCode: _locale.languageCode,
    );
  }

  void _completeTutorial() {
    setState(() => _tutorialSeen = true);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_kTutorialKey, true));
    AnalyticsService.instance.logTutorialComplete();
  }

  Future<void> _checkForUpdate(BuildContext ctx) async {
    if (_updateCheckDone || kIsWeb) return;
    _updateCheckDone = true;

    final info = await UpdateService.checkForUpdate(_locale.languageCode);
    if (info == null || !info.needsUpdate) {
      // No update needed — check for post-update What's New
      if (info != null) _showPostUpdateWhatsNew(ctx, info);
      return;
    }

    if (!ctx.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!info.isForced) {
      final dismissed = prefs.getInt(_kDismissedUpdateVersion) ?? 0;
      if (dismissed >= info.latestVersionCode) return;
    }

    if (!ctx.mounted) return;
    _showUpdateDialog(ctx, info, prefs);
  }

  Future<void> _showPostUpdateWhatsNew(
      BuildContext ctx, UpdateInfo info) async {
    if (info.whatsNewText.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final lastBuild = prefs.getInt(_kLastWhatsNewBuild) ?? 0;
    if (info.currentVersionCode <= lastBuild) return;

    await prefs.setInt(_kLastWhatsNewBuild, info.currentVersionCode);
    if (!ctx.mounted) return;

    final isAr = _locale.languageCode == 'ar';
    showDialog(
      context: ctx,
      builder: (dCtx) => _UpdateDialog(
        title: AppStrings.tFor(_locale.languageCode, 'whats_new'),
        whatsNew: info.whatsNewText,
        isForced: false,
        isPostUpdate: true,
        isAr: isAr,
      ),
    );
  }

  void _showUpdateDialog(
      BuildContext ctx, UpdateInfo info, SharedPreferences prefs) {
    final isAr = _locale.languageCode == 'ar';
    final title = info.isForced
        ? AppStrings.tFor(_locale.languageCode, 'update_required')
        : AppStrings.tFor(_locale.languageCode, 'update_available');

    showDialog(
      context: ctx,
      barrierDismissible: !info.isForced,
      builder: (dCtx) => PopScope(
        canPop: !info.isForced,
        child: _UpdateDialog(
          title: title,
          whatsNew: info.whatsNewText,
          isForced: info.isForced,
          isPostUpdate: false,
          isAr: isAr,
          forcedMessage: info.isForced
              ? AppStrings.tFor(_locale.languageCode, 'update_required_msg')
              : null,
          onLater: info.isForced
              ? null
              : () {
                  prefs.setInt(
                      _kDismissedUpdateVersion, info.latestVersionCode);
                  Navigator.pop(dCtx);
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InstaGold',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [AnalyticsService.instance.observer],
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
            if (snapshot.connectionState == ConnectionState.waiting ||
                !_settingsLoaded) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (!_tutorialSeen) {
              return TutorialScreen(onComplete: _completeTutorial);
            }
            if (!snapshot.hasData && !_guestMode) {
              return LoginScreen(
                authService: _authService,
                onGuestLogin: () {
                  setState(() => _guestMode = true);
                  SharedPreferences.getInstance()
                      .then((p) => p.setBool(_kGuestKey, true));
                  AnalyticsService.instance.logGuestLogin();
                },
              );
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _ensurePushInitialized();
              if (context.mounted) _checkForUpdate(context);
            });
            return DashboardScreen(
              authService: _authService,
              apiService: _guestMode
                  ? ApiService.devBypass()
                  : ApiService(_authService),
              locale: _locale,
              themeMode: _themeMode,
              notificationsService: _notificationsService,
              pushNotificationsService: _pushService,
              onLocaleChanged: _handleLocaleChanged,
              onThemeChanged: _handleThemeChanged,
              onReplayTutorial: () {
                setState(() => _tutorialSeen = false);
                SharedPreferences.getInstance()
                    .then((p) => p.setBool(_kTutorialKey, false));
              },
              onLogout: () {
                setState(() => _guestMode = false);
                SharedPreferences.getInstance()
                    .then((p) => p.setBool(_kGuestKey, false));
              },
            );
          },
        ),
      ),
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  final String title;
  final String whatsNew;
  final bool isForced;
  final bool isPostUpdate;
  final bool isAr;
  final String? forcedMessage;
  final VoidCallback? onLater;

  const _UpdateDialog({
    required this.title,
    required this.whatsNew,
    required this.isForced,
    required this.isPostUpdate,
    required this.isAr,
    this.forcedMessage,
    this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = isAr;
    final localeCode = isAr ? 'ar' : 'en';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isPostUpdate ? Icons.celebration_rounded : Icons.system_update,
              color: const Color(0xFFD4A843),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              )),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (forcedMessage != null) ...[
                Text(forcedMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error)),
                const SizedBox(height: 12),
              ],
              if (whatsNew.isNotEmpty) ...[
                Text(
                  AppStrings.tFor(localeCode, 'whats_new'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD4A843),
                  ),
                ),
                const SizedBox(height: 8),
                Text(whatsNew, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        actions: [
          if (!isForced && !isPostUpdate && onLater != null)
            TextButton(
              onPressed: onLater,
              child: Text(AppStrings.tFor(localeCode, 'later')),
            ),
          if (isPostUpdate)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD4A843),
              ),
              child: Text(AppStrings.tFor(localeCode, 'got_it')),
            )
          else
            FilledButton.icon(
              onPressed: () {
                launchUrl(Uri.parse(UpdateService.storeUrl),
                    mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.download_rounded),
              label: Text(AppStrings.tFor(localeCode, 'update_now')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD4A843),
              ),
            ),
        ],
      ),
    );
  }
}
