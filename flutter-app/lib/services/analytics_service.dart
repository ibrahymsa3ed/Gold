import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Centralised wrapper around Firebase Analytics.
///
/// All custom event names follow Firebase conventions (snake_case, ≤40 chars).
/// Call [AnalyticsService.instance] anywhere — it's a lazy singleton.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  void _log(String name, [Map<String, Object>? params]) {
    if (kDebugMode) return;
    _analytics.logEvent(name: name, parameters: params);
  }

  // ── Auth ──────────────────────────────────────────────────────────────

  void logLogin(String method) =>
      _analytics.logLogin(loginMethod: method);

  void logGuestLogin() => _log('guest_login');

  // ── Tutorial ──────────────────────────────────────────────────────────

  void logTutorialComplete() => _log('tutorial_complete');

  void logTutorialSkip({required int slideIndex}) =>
      _log('tutorial_skip', {'slide_index': slideIndex});

  // ── Tab Navigation ────────────────────────────────────────────────────

  void logTabView(String tabName) =>
      _log('tab_view', {'tab_name': tabName});

  // ── Members ───────────────────────────────────────────────────────────

  void logMemberAdded() => _log('member_added');

  // ── Assets ────────────────────────────────────────────────────────────

  void logAssetAdded({required String type, required String karat}) =>
      _log('asset_added', {'asset_type': type, 'karat': karat});

  void logAssetEdited({required String type}) =>
      _log('asset_edited', {'asset_type': type});

  void logAssetDeleted() => _log('asset_deleted');

  void logAssetsToggleHidden(bool hidden) =>
      _log('assets_toggle_hidden', {'hidden': hidden.toString()});

  // ── Savings ───────────────────────────────────────────────────────────

  void logSavingAdded() => _log('saving_added');

  void logSavingEdited() => _log('saving_edited');

  void logSavingDeleted() => _log('saving_deleted');

  // ── Goals ─────────────────────────────────────────────────────────────

  void logGoalAdded({required String type, required String karat}) =>
      _log('goal_added', {'goal_type': type, 'karat': karat});

  void logGoalDeleted() => _log('goal_deleted');

  // ── Price Alerts ──────────────────────────────────────────────────────

  void logPriceAlertCreated({
    required String karat,
    required String direction,
  }) =>
      _log('price_alert_created', {'karat': karat, 'direction': direction});

  void logPriceAlertDeleted() => _log('price_alert_deleted');

  void logPriceAlertToggled(bool active) =>
      _log('price_alert_toggled', {'active': active.toString()});

  void logPriceAlertsOpened() => _log('price_alerts_opened');

  // ── Ingot & Coin Calculator ───────────────────────────────────────────

  void logIngotCalcOpened() => _log('ingot_calc_opened');

  void logIngotCalcCompanyChanged(String companyId) =>
      _log('ingot_calc_company', {'company_id': companyId});

  void logIngotCalcTabChanged(String tab) =>
      _log('ingot_calc_tab', {'tab': tab});

  // ── Gold Calculator ───────────────────────────────────────────────────

  void logGoldCalcUsed() => _log('gold_calc_used');

  // ── Backup / Restore ──────────────────────────────────────────────────

  void logBackupExported(String destination) =>
      _log('backup_exported', {'destination': destination});

  void logBackupImported() => _log('backup_imported');

  // ── Settings ──────────────────────────────────────────────────────────

  void logThemeChanged(String theme) =>
      _log('theme_changed', {'theme': theme});

  void logLanguageChanged(String language) =>
      _log('language_changed', {'language': language});
}
