import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../l10n.dart';
import '../screens/price_alerts_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/google_drive_service.dart';
import '../services/gold_scraper.dart';
import '../services/invoice_attachment_service.dart';
import '../services/notifications_service.dart';
import '../services/push_notifications_service.dart';
import '../theme/app_themes.dart';
import '../widgets/ig_logo.dart';
import '../widgets/instagold_ad_banner.dart';
import '../widgets/premium_background.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.authService,
    required this.apiService,
    required this.notificationsService,
    this.pushNotificationsService,
    required this.locale,
    required this.themeMode,
    required this.onLocaleChanged,
    required this.onThemeChanged,
    this.onLogout,
  });

  final AuthService authService;
  final ApiService apiService;
  final NotificationsService notificationsService;
  final PushNotificationsService? pushNotificationsService;
  final Locale locale;
  final ThemeMode themeMode;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback? onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  List<dynamic> _members = [];
  List<dynamic> _assets = [];
  List<dynamic> _goals = [];
  List<dynamic> _companies = [];
  List<dynamic> _savingEntries = [];
  double _totalSaved = 0;
  Map<String, dynamic>? _prices;
  int? _selectedMemberId;
  int? _defaultMemberId;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _zakat;
  double? _usdEgpRate;
  int _selectedTab = 0;
  bool _busy = false;
  bool _loading = true;
  final NumberFormat _currency = NumberFormat('#,##0.##');

  List<String> _priceCardOrder = ['21k', '24k', '14k_18k', 'pound_ounce'];

  // Calculator panel state
  String _calcKarat = '21k';
  final TextEditingController _calcWeightCtrl = TextEditingController();
  final TextEditingController _calcMfgCtrl = TextEditingController();
  final TextEditingController _calcTaxCtrl =
      TextEditingController(text: '10');
  bool _calcExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load().then((_) {
      _afterPricesLoaded();
      _maybShowMiuiBatteryPrompt();
    });
    _loadCardOrder();
  }

  Future<void> _loadCardOrder() async {
    final prefs = await SharedPreferences.getInstance();
    const _kCardOrderKey = 'price_card_order';
    final stored = prefs.getStringList(_kCardOrderKey);
    if (stored != null && stored.isNotEmpty) {
      setState(() => _priceCardOrder = stored);
    }
  }

  Future<void> _saveCardOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('price_card_order', _priceCardOrder);
  }

  Future<void> _maybShowMiuiBatteryPrompt() async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    const _kMiuiPromptShown = 'miui_battery_prompt_shown';
    if (prefs.getBool(_kMiuiPromptShown) == true) return;

    try {
      final info = DeviceInfoPlugin();
      final android = await info.androidInfo;
      final manufacturer = android.manufacturer.toLowerCase();
      if (!manufacturer.contains('xiaomi') && !manufacturer.contains('redmi')) return;
    } catch (_) {
      return;
    }

    await prefs.setBool(_kMiuiPromptShown, true);

    if (!mounted) return;
    final ar = AppStrings.isAr(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'تحسين البطارية' : 'Battery Optimization'),
        content: Text(
          ar
              ? 'لضمان وصول الإشعارات في الوقت المحدد، يُرجى إضافة InstaGold إلى قائمة التطبيقات غير المقيّدة في إعدادات البطارية.'
              : 'To ensure notifications arrive on time, please allow InstaGold to run without battery restrictions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ar ? 'لاحقاً' : 'Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              const channel = MethodChannel('com.ibrahym.instagold/settings');
              channel.invokeMethod('openBatterySettings').catchError((_) {});
            },
            child: Text(ar ? 'الإعدادات' : 'Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calcWeightCtrl.dispose();
    _calcMfgCtrl.dispose();
    _calcTaxCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load().then((_) => _afterPricesLoaded());
    }
  }

  void _afterPricesLoaded() {
    // Sell-only feed for home-screen widget + notification banner. The
    // dashboard UI renders its own buy/sell columns directly from `_prices`
    // and is unaffected by what we read here.
    final pricesMap = _prices?['prices'] as Map<String, dynamic>? ?? {};
    final p21 = (pricesMap['21k'] as Map<String, dynamic>?)?['sell_price'] as num?;
    final p24 = (pricesMap['24k'] as Map<String, dynamic>?)?['sell_price'] as num?;
    final ounce = (pricesMap['ounce'] as Map<String, dynamic>?)?['sell_price'] as num?;

    // Push to home widget (iOS + Android)
    _updateHomeWidget(p21?.toDouble(), p24?.toDouble(), ounce?.toDouble());

    // Foreground guarantee: fire a price notification if at least 1 hour has
    // passed since the last one. This complements the background WorkManager
    // task and ensures notifications work even when background execution is
    // restricted (e.g., MIUI/Xiaomi or aggressive battery savers).
    _maybeFireForegroundNotification(
        p21?.toDouble(), p24?.toDouble(), ounce?.toDouble());
  }

  Future<void> _maybeFireForegroundNotification(
      double? p21, double? p24, double? ounce) async {
    if (kIsWeb) return;
    if (p21 == null && p24 == null && ounce == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      const slotKey = 'pw_last_slot';

      // Check if we are inside a Cairo fixed-time slot window.
      tz.initializeTimeZones();
      final cairo = tz.getLocation('Africa/Cairo');
      final now = tz.TZDateTime.now(cairo);
      const slots = [7, 11, 15, 19];
      const quietStart = 23;
      const quietEnd = 7;

      if (now.hour >= quietStart || now.hour < quietEnd) return;

      String? currentSlot;
      for (final h in slots) {
        if (now.hour == h && now.minute < 30) {
          currentSlot =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}#$h';
          break;
        }
      }
      if (currentSlot == null) return;

      final lastSlot = prefs.getString(slotKey);
      if (lastSlot == currentSlot) {
        debugPrint('InstaGold: foreground slot $currentSlot already sent');
        return;
      }

      // Skip local notification when FCM is active — server push covers it.
      final fcmActive = await PushNotificationsService.isFcmActive();
      if (fcmActive) {
        await prefs.setString(slotKey, currentSlot);
        debugPrint('InstaGold: FCM active, skipping foreground notif for $currentSlot');
        return;
      }

      final body = NotificationsService.buildPriceBody(
        price21k: p21,
        price24k: p24,
        priceOunce: ounce,
        localeCode: widget.locale.languageCode,
      );
      await widget.notificationsService.showPriceChangeNotification(
        title: 'InstaGold',
        body: body,
      );
      await prefs.setString(slotKey, currentSlot);
      debugPrint('InstaGold: foreground notification fired for slot $currentSlot');
    } catch (e) {
      debugPrint('InstaGold: foreground notif failed: $e');
    }
  }

  Future<void> _updateHomeWidget(
      double? p21, double? p24, double? ounce) async {
    try {
      if (p21 != null) {
        await HomeWidget.saveWidgetData<double>('price_21k', p21);
      }
      if (p24 != null) {
        await HomeWidget.saveWidgetData<double>('price_24k', p24);
      }
      if (ounce != null) {
        await HomeWidget.saveWidgetData<double>('price_ounce', ounce);
      }
      await HomeWidget.saveWidgetData<String>(
          'updated_at', DateTime.now().toIso8601String());
      await HomeWidget.updateWidget(
        name: 'InstaGoldWidgetProvider',
        iOSName: 'InstaGoldWidget',
        qualifiedAndroidName:
            'com.ibrahym.instagold.InstaGoldWidgetProvider',
      );
      debugPrint('InstaGold: widget updated p21=$p21 p24=$p24 oz=$ounce');
    } catch (e) {
      debugPrint('InstaGold: widget update failed: $e');
    }
  }

  void _persistSettings() {
    _safeAction(() async {
      await widget.apiService.updateSettings(
        locale: widget.locale.languageCode,
        theme: widget.themeMode == ThemeMode.dark ? 'dark' : 'light',
        notificationIntervalHours: 4,
      );
    });
  }

  Future<void> _safeAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final errors = <String>[];
    try {
      try {
        await widget.apiService.createSession();
      } catch (_) {/* session is optional */}

      Map<String, dynamic>? prices;
      try {
        await widget.apiService.syncPrices();
        prices = await widget.apiService.getCurrentPrices();
      } catch (e) {
        // Sync failed — try reading cached prices
        try {
          prices = await widget.apiService.getCurrentPrices();
        } catch (_) {}
        if (prices == null ||
            (prices['prices'] as Map?)?.isEmpty == true) {
          errors.add('Prices: ${_cleanErrorMessage(e)}');
        }
      }

      // Fetch exchange rate for دولار الصاغه (works on both web and mobile)
      try {
        final pricesMap = prices?['prices'] as Map<String, dynamic>? ?? {};
        final rateFromCache =
            pricesMap['usd_egp_rate'] as Map<String, dynamic>?;
        if (rateFromCache != null) {
          _usdEgpRate = (rateFromCache['sell_price'] as num?)?.toDouble();
        } else {
          _usdEgpRate = await GoldScraper.fetchUsdEgpRate();
        }
      } catch (_) {}

      List<dynamic> members = [];
      try {
        members = await widget.apiService.getMembers();
      } catch (e) {
        errors.add('Members: ${_cleanErrorMessage(e)}');
      }

      List<dynamic> companies = [];
      try {
        companies = await widget.apiService.getCompanies();
      } catch (e) {
        errors.add('Companies: ${_cleanErrorMessage(e)}');
      }

      Map<String, dynamic>? summary;
      Map<String, dynamic>? zakat;
      List<dynamic> assets = [];
      List<dynamic> goals = [];
      List<dynamic> savingEntries = [];
      double totalSaved = 0;
      int? selectedId;
      if (members.isNotEmpty) {
        try {
          final defaultId = await widget.apiService.getDefaultMemberId();
          _defaultMemberId = defaultId;
          if (_selectedMemberId == null &&
              defaultId != null &&
              members.any((m) => m['id'] == defaultId)) {
            _selectedMemberId = defaultId;
          }
        } catch (_) {}
        selectedId = _selectedMemberId ?? members.first['id'] as int;
        try {
          final results = await Future.wait([
            widget.apiService.getMemberSummary(selectedId),
            widget.apiService.getMemberZakat(selectedId),
            widget.apiService.getMemberAssets(selectedId),
            widget.apiService.getGoals(selectedId),
            widget.apiService.getSavings(selectedId),
          ]);
          summary = results[0] as Map<String, dynamic>;
          zakat = results[1] as Map<String, dynamic>;
          assets = results[2] as List<dynamic>;
          goals = results[3] as List<dynamic>;
          final savingsData = results[4] as Map<String, dynamic>;
          savingEntries = (savingsData['entries'] as List<dynamic>? ?? []);
          totalSaved = (savingsData['total_saved'] as num?)?.toDouble() ?? 0;
        } catch (e) {
          errors.add('Details: ${_cleanErrorMessage(e)}');
        }
      }
      setState(() {
        _prices = prices;
        _members = members;
        _companies = companies;
        _selectedMemberId = selectedId;
        _summary = summary;
        _zakat = zakat;
        _assets = assets;
        _goals = goals;
        _savingEntries = savingEntries;
        _totalSaved = totalSaved;
      });
    } catch (error) {
      errors.add(_cleanErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
      if (errors.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errors.join(' | ')),
              duration: const Duration(seconds: 5)),
        );
      }
      if (mounted && _members.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _members.isEmpty) _forceCreateMember();
        });
      }
    }
  }

  Future<void> _forceCreateMember() async {
    final name = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t(ctx, 'add_member')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.t(ctx, 'first_member_hint'),
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration:
                    InputDecoration(labelText: AppStrings.t(ctx, 'name')),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.t(ctx, 'save')),
          ),
        ],
      ),
    );
    if (saved == true && name.text.trim().isNotEmpty) {
      await _safeAction(() async {
        final member = await widget.apiService.addMember(name.text.trim());
        await widget.apiService.setDefaultMemberId(member['id'] as int);
        await _load();
      });
    } else if (_members.isEmpty) {
      _forceCreateMember();
    }
  }

  String _cleanErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw;
  }

  Future<void> _memberDialog({Map<String, dynamic>? existing}) async {
    final name =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final isEdit = existing != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit
            ? AppStrings.t(ctx, 'edit_member')
            : AppStrings.t(ctx, 'add_member')),
        content: SingleChildScrollView(
          child: TextField(
            controller: name,
            decoration: InputDecoration(labelText: AppStrings.t(ctx, 'name')),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Row(
            children: [
              if (isEdit)
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (ctx2) => AlertDialog(
                        title: Text(AppStrings.t(ctx2, 'confirm_delete')),
                        content: Text(AppStrings.t(ctx2, 'confirm_delete_msg')),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx2, false),
                              child: Text(AppStrings.t(ctx2, 'cancel'))),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx2, true),
                            child: Text(AppStrings.t(ctx2, 'delete'),
                                style: const TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && ctx.mounted) {
                      Navigator.pop(ctx, false);
                      await _safeAction(() async {
                        await widget.apiService
                            .deleteMember(existing['id'] as int);
                        _selectedMemberId = null;
                        await _load();
                      });
                    }
                  },
                  child: Text(AppStrings.t(ctx, 'delete'),
                      style: const TextStyle(color: Colors.red)),
                ),
              const Spacer(),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(AppStrings.t(ctx, 'cancel'))),
              const SizedBox(width: 8),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(AppStrings.t(ctx, 'save'))),
            ],
          ),
        ],
      ),
    );
    if (saved == true && name.text.trim().isNotEmpty) {
      await _safeAction(() async {
        if (isEdit) {
          await widget.apiService
              .updateMember(existing['id'] as int, name.text.trim());
        } else {
          await widget.apiService.addMember(name.text.trim());
        }
        await _load();
      });
    }
  }

  static const _mainAssetTypes = ['jewellery', 'coins', 'ingot'];
  static const _jewellerySubTypes = ['ring', 'necklace', 'bracelet', 'other'];
  static const _karatOptions = ['24k', '21k', '18k', '14k'];
  static const _defaultKarats = {'coins': '21k', 'ingot': '24k'};

  static const _coinSizes = {
    '5_pounds': {'label': '5 Pounds', 'grams': 40.0},
    'pound': {'label': 'Pound', 'grams': 8.0},
    'half_pound': {'label': 'Half Pound', 'grams': 4.0},
    'quarter_pound': {'label': 'Quarter Pound', 'grams': 2.0},
    'manual': {'label': 'Manual', 'grams': 0.0},
  };

  static const _ingotSizes = {
    '1g': {'label': '1 G', 'grams': 1.0},
    '5g': {'label': '5 G', 'grams': 5.0},
    '10g': {'label': '10 G', 'grams': 10.0},
    '20g': {'label': '20 G', 'grams': 20.0},
    'ounce': {'label': 'Ounce (31.1 G)', 'grams': 31.1},
    'manual': {'label': 'Manual', 'grams': 0.0},
  };

  String _mainTypeOf(String assetType) {
    if (_jewellerySubTypes.contains(assetType)) return 'jewellery';
    if (_mainAssetTypes.contains(assetType)) return assetType;
    return 'jewellery';
  }

  Future<void> _addAssetDialog({Map<String, dynamic>? existing}) async {
    if (_selectedMemberId == null) return;

    final rawType = existing?['asset_type']?.toString() ?? 'ring';
    String selectedMainType = _mainTypeOf(rawType);
    final bool isOtherJewellery = !_jewellerySubTypes.contains(rawType) &&
        selectedMainType == 'jewellery' &&
        existing != null;
    String selectedSubType = _jewellerySubTypes.contains(rawType)
        ? rawType
        : (isOtherJewellery ? 'other' : 'ring');
    final customName =
        TextEditingController(text: isOtherJewellery ? rawType : '');
    String selectedCoinSize = 'pound';
    String selectedIngotSize = '10g';
    String selectedKarat = existing?['karat']?.toString() ?? '21k';
    final weight =
        TextEditingController(text: existing?['weight_g']?.toString() ?? '');
    final purchasePrice = TextEditingController(
        text: existing?['purchase_price']?.toString() ?? '');
    DateTime selectedDate =
        DateTime.tryParse(existing?['purchase_date']?.toString() ?? '') ??
            DateTime.now();
    int? companyId = existing?['company_id'] as int?;
    bool weightLocked = false;
    String? invoicePath = existing?['invoice_local_path']?.toString();
    var removeInvoice = false;
    final invService = InvoiceAttachmentService();

    String effectiveType() {
      if (selectedMainType == 'jewellery') {
        return selectedSubType == 'other'
            ? (customName.text.trim().isEmpty
                ? 'other'
                : customName.text.trim())
            : selectedSubType;
      }
      return selectedMainType;
    }

    if (_defaultKarats.containsKey(selectedMainType) && existing == null) {
      selectedKarat = _defaultKarats[selectedMainType]!;
    }

    void applySizeWeight(StateSetter setDialogState) {
      if (selectedMainType == 'coins' && selectedCoinSize != 'manual') {
        final g = (_coinSizes[selectedCoinSize]!['grams']! as num).toString();
        weight.text = g;
        weightLocked = true;
      } else if (selectedMainType == 'ingot' && selectedIngotSize != 'manual') {
        final g = (_ingotSizes[selectedIngotSize]!['grams']! as num).toString();
        weight.text = g;
        weightLocked = true;
      } else {
        weightLocked = false;
      }
      setDialogState(() {});
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(existing == null
                ? AppStrings.t(context, 'add_asset')
                : AppStrings.t(context, 'edit_asset')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedMainType,
                    decoration: InputDecoration(
                        labelText: AppStrings.t(context, 'asset_type')),
                    items: _mainAssetTypes.map((t) {
                      return DropdownMenuItem(
                          value: t, child: Text(AppStrings.t(context, t)));
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      selectedMainType = value;
                      if (_defaultKarats.containsKey(value)) {
                        selectedKarat = _defaultKarats[value]!;
                      }
                      weightLocked = false;
                      weight.text = '';
                      applySizeWeight(setDialogState);
                    },
                  ),
                  if (selectedMainType == 'jewellery') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('jewellery_sub'),
                      value: selectedSubType,
                      decoration: InputDecoration(
                          labelText: AppStrings.t(context, 'jewellery_type')),
                      items: _jewellerySubTypes.map((t) {
                        return DropdownMenuItem(
                            value: t, child: Text(_assetTypeLabel(t)));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null)
                          setDialogState(() => selectedSubType = value);
                      },
                    ),
                    if (selectedSubType == 'other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customName,
                        decoration: InputDecoration(
                            labelText: AppStrings.t(context, 'custom_name')),
                      ),
                    ],
                  ],
                  if (selectedMainType == 'coins') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('coin_size'),
                      value: selectedCoinSize,
                      decoration: InputDecoration(
                          labelText: AppStrings.t(context, 'coin_size')),
                      items: _coinSizes.entries.map((e) {
                        final g = (e.value['grams']! as num);
                        final suffix = g > 0 ? ' (${g}g)' : '';
                        return DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.value['label']}$suffix'));
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        selectedCoinSize = value;
                        applySizeWeight(setDialogState);
                      },
                    ),
                  ],
                  if (selectedMainType == 'ingot') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('ingot_size'),
                      value: selectedIngotSize,
                      decoration: InputDecoration(
                          labelText: AppStrings.t(context, 'ingot_size')),
                      items: _ingotSizes.entries.map((e) {
                        return DropdownMenuItem(
                            value: e.key, child: Text('${e.value['label']}'));
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        selectedIngotSize = value;
                        applySizeWeight(setDialogState);
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('karat_$selectedMainType'),
                    value: selectedKarat,
                    decoration: InputDecoration(
                      labelText: _defaultKarats.containsKey(selectedMainType)
                          ? '${AppStrings.t(context, 'karat')} (${AppStrings.t(context, 'karat_default_hint')} ${_karatLabelFromKey(_defaultKarats[selectedMainType]!)})'
                          : AppStrings.t(context, 'karat'),
                    ),
                    items: _karatOptions
                        .map((k) => DropdownMenuItem(
                            value: k, child: Text(_karatLabelFromKey(k))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null)
                        setDialogState(() => selectedKarat = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    readOnly: weightLocked,
                    decoration: InputDecoration(
                      labelText: AppStrings.t(context, 'weight_g'),
                      suffixIcon: weightLocked
                          ? const Icon(Icons.lock_outline, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: purchasePrice,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                        labelText: AppStrings.t(context, 'purchase_price')),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: AppStrings.t(context, 'purchase_date'),
                        suffixIcon: const Icon(Icons.calendar_today, size: 20),
                      ),
                      child:
                          Text(selectedDate.toIso8601String().split('T').first),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: companyId,
                    decoration: InputDecoration(
                        labelText: AppStrings.t(context, 'company_optional')),
                    items: [
                      DropdownMenuItem<int?>(
                          value: null,
                          child: Text(AppStrings.t(context, 'none'))),
                      ..._companies.map((company) {
                        return DropdownMenuItem<int?>(
                          value: company['id'] as int,
                          child: Text(company['name'].toString()),
                        );
                      }),
                    ],
                    onChanged: (value) => companyId = value,
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        AppStrings.t(context, 'attach_invoice'),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final r = await FilePicker.platform.pickFiles();
                            if (r != null && r.files.isNotEmpty) {
                              final path = await invService
                                  .copyPickedToAppStorage(r.files.single);
                              setDialogState(() {
                                invoicePath = path;
                                removeInvoice = false;
                              });
                            }
                          },
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: Text(
                            invoicePath != null && !removeInvoice
                                ? p.basename(invoicePath!)
                                : '—',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if ((invoicePath != null && !removeInvoice) ||
                            (existing?['invoice_local_path'] != null &&
                                !removeInvoice &&
                                invoicePath == null))
                          TextButton(
                            onPressed: () => setDialogState(() {
                              removeInvoice = true;
                              invoicePath = null;
                            }),
                            child: Text(
                                AppStrings.t(context, 'remove_attachment')),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(AppStrings.t(context, 'cancel'))),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(AppStrings.t(context, 'save'))),
            ],
          );
        },
      ),
    );
    if (saved != true) return;

    final weightValue = double.tryParse(weight.text) ?? 0;
    final purchaseValue = double.tryParse(purchasePrice.text) ?? 0;
    if (weightValue <= 0 || purchaseValue <= 0) return;

    final finalType = effectiveType();
    await _safeAction(() async {
      if (existing == null) {
        await widget.apiService.addAsset(
          memberId: _selectedMemberId!,
          assetType: finalType,
          karat: selectedKarat,
          weightG: weightValue,
          purchasePrice: purchaseValue,
          purchaseDate: selectedDate.toIso8601String().split('T').first,
          companyId: companyId,
          invoiceLocalPath: kIsWeb ? null : invoicePath,
        );
      } else {
        final oldInv = existing['invoice_local_path'] as String?;
        if (!kIsWeb) {
          if (removeInvoice && oldInv != null) {
            await invService.deleteFileIfExists(oldInv);
            await widget.apiService.updateAsset(
              assetId: existing['id'] as int,
              assetType: finalType,
              karat: selectedKarat,
              weightG: weightValue,
              purchasePrice: purchaseValue,
              purchaseDate: selectedDate.toIso8601String().split('T').first,
              companyId: companyId,
              clearInvoice: true,
            );
          } else if (invoicePath != null && invoicePath != oldInv) {
            await invService.deleteFileIfExists(oldInv);
            await widget.apiService.updateAsset(
              assetId: existing['id'] as int,
              assetType: finalType,
              karat: selectedKarat,
              weightG: weightValue,
              purchasePrice: purchaseValue,
              purchaseDate: selectedDate.toIso8601String().split('T').first,
              companyId: companyId,
              invoiceLocalPath: invoicePath,
            );
          } else {
            await widget.apiService.updateAsset(
              assetId: existing['id'] as int,
              assetType: finalType,
              karat: selectedKarat,
              weightG: weightValue,
              purchasePrice: purchaseValue,
              purchaseDate: selectedDate.toIso8601String().split('T').first,
              companyId: companyId,
            );
          }
        } else {
          await widget.apiService.updateAsset(
            assetId: existing['id'] as int,
            assetType: finalType,
            karat: selectedKarat,
            weightG: weightValue,
            purchasePrice: purchaseValue,
            purchaseDate: selectedDate.toIso8601String().split('T').first,
            companyId: companyId,
          );
        }
      }
      await _load();
    });
  }

  Future<void> _addSavingDialog() async {
    if (_selectedMemberId == null) return;
    final amount = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t(context, 'add_saving')),
        content: TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(labelText: AppStrings.t(context, 'amount')),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.t(context, 'cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.t(context, 'save'))),
        ],
      ),
    );
    if (saved != true) return;
    final value = double.tryParse(amount.text) ?? 0;
    if (value <= 0) return;

    await _safeAction(() async {
      await widget.apiService.addSaving(_selectedMemberId!, value);
      await _load();
    });
  }

  Future<void> _editSavingDialog(Map<String, dynamic> entry) async {
    final amount = TextEditingController(
        text: (entry['amount'] as num?)?.toString() ?? '');
    final id = entry['id'] as int;

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t(context, 'edit_saving')),
        content: TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(labelText: AppStrings.t(context, 'amount')),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: Text(AppStrings.t(context, 'delete'),
                style: const TextStyle(color: Colors.red)),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.t(context, 'cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text(AppStrings.t(context, 'save'))),
        ],
      ),
    );
    if (result == null) return;
    if (result == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppStrings.t(context, 'confirm_delete')),
          content: Text(AppStrings.t(context, 'confirm_delete_msg')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppStrings.t(context, 'cancel'))),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.t(context, 'delete'),
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await _safeAction(() async {
        await widget.apiService.deleteSaving(id);
        await _load();
      });
      return;
    }
    final value = double.tryParse(amount.text) ?? 0;
    if (value <= 0) return;
    await _safeAction(() async {
      await widget.apiService.updateSaving(id, value);
      await _load();
    });
  }

  Future<void> _addGoalDialog() async {
    if (_selectedMemberId == null) return;
    String goalMainType = 'jewellery';
    String goalSubType = 'ring';
    final goalCustomName = TextEditingController();
    String goalCoinSize = 'pound';
    String goalIngotSize = '10g';
    String goalKarat = '21k';
    final targetWeight = TextEditingController();
    final manufacturingPriceCtrl = TextEditingController();
    int? companyId;
    bool goalWeightLocked = false;

    void applyGoalWeight(StateSetter setDialogState) {
      if (goalMainType == 'coins' && goalCoinSize != 'manual') {
        targetWeight.text =
            (_coinSizes[goalCoinSize]!['grams']! as num).toString();
        goalWeightLocked = true;
      } else if (goalMainType == 'ingot' && goalIngotSize != 'manual') {
        targetWeight.text =
            (_ingotSizes[goalIngotSize]!['grams']! as num).toString();
        goalWeightLocked = true;
      } else {
        goalWeightLocked = false;
      }
      setDialogState(() {});
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(AppStrings.t(context, 'add_goal')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: goalMainType,
                    decoration: InputDecoration(
                        labelText: AppStrings.t(context, 'goal_type')),
                    items: _mainAssetTypes.map((t) {
                      return DropdownMenuItem(
                          value: t, child: Text(AppStrings.t(context, t)));
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      goalMainType = value;
                      if (_defaultKarats.containsKey(value)) {
                        goalKarat = _defaultKarats[value]!;
                      }
                      goalWeightLocked = false;
                      targetWeight.text = '';
                      applyGoalWeight(setDialogState);
                    },
                  ),
                  if (goalMainType == 'jewellery') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('goal_jewellery_sub'),
                      value: goalSubType,
                      decoration: InputDecoration(
                          labelText: AppStrings.t(context, 'jewellery_type')),
                      items: _jewellerySubTypes.map((t) {
                        return DropdownMenuItem(
                            value: t, child: Text(_assetTypeLabel(t)));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null)
                          setDialogState(() => goalSubType = value);
                      },
                    ),
                    if (goalSubType == 'other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: goalCustomName,
                        decoration: InputDecoration(
                            labelText: AppStrings.t(context, 'custom_name')),
                      ),
                    ],
                  ],
                  if (goalMainType == 'coins') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('goal_coin_size'),
                      value: goalCoinSize,
                      decoration: InputDecoration(
                          labelText: AppStrings.t(context, 'coin_size')),
                      items: _coinSizes.entries.map((e) {
                        final g = (e.value['grams']! as num);
                        final suffix = g > 0 ? ' (${g}g)' : '';
                        return DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.value['label']}$suffix'));
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        goalCoinSize = value;
                        applyGoalWeight(setDialogState);
                      },
                    ),
                  ],
                  if (goalMainType == 'ingot') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('goal_ingot_size'),
                      value: goalIngotSize,
                      decoration: InputDecoration(
                          labelText: AppStrings.t(context, 'ingot_size')),
                      items: _ingotSizes.entries.map((e) {
                        return DropdownMenuItem(
                            value: e.key, child: Text('${e.value['label']}'));
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        goalIngotSize = value;
                        applyGoalWeight(setDialogState);
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('goal_karat_$goalMainType'),
                    value: goalKarat,
                    decoration: InputDecoration(
                      labelText: _defaultKarats.containsKey(goalMainType)
                          ? '${AppStrings.t(context, 'karat')} (${AppStrings.t(context, 'karat_default_hint')} ${_karatLabelFromKey(_defaultKarats[goalMainType]!)})'
                          : AppStrings.t(context, 'karat'),
                    ),
                    items: _karatOptions
                        .map((k) => DropdownMenuItem(
                            value: k, child: Text(_karatLabelFromKey(k))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null)
                        setDialogState(() => goalKarat = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: targetWeight,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    readOnly: goalWeightLocked,
                    decoration: InputDecoration(
                      labelText: AppStrings.t(context, 'target_weight'),
                      suffixIcon: goalWeightLocked
                          ? const Icon(Icons.lock_outline, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: companyId,
                    decoration: InputDecoration(
                        labelText: AppStrings.t(context, 'company_optional')),
                    items: [
                      DropdownMenuItem<int?>(
                          value: null,
                          child: Text(AppStrings.t(context, 'none'))),
                      ..._companies.map((company) => DropdownMenuItem<int?>(
                            value: company['id'] as int,
                            child: Text(company['name'].toString()),
                          )),
                    ],
                    onChanged: (value) => companyId = value,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: manufacturingPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: AppStrings.t(context, 'manufacturing_price'),
                      hintText: '0.00',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(AppStrings.t(context, 'cancel'))),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(AppStrings.t(context, 'save'))),
            ],
          );
        },
      ),
    );
    if (saved != true) return;
    await _safeAction(() async {
      await widget.apiService.createGoal(
        memberId: _selectedMemberId!,
        karat: goalKarat,
        targetWeightG: double.tryParse(targetWeight.text) ?? 0,
        savedAmount: 0,
        companyId: companyId,
        manufacturingPriceG:
            double.tryParse(manufacturingPriceCtrl.text) ?? 0,
      );
      await _load();
    });
  }

  Future<void> _editGoalDialog(Map<String, dynamic> goal) async {
    var goalKarat = goal['karat']?.toString() ?? '21k';
    final targetWeight = TextEditingController(
        text: (goal['target_weight_g'] as num?)?.toString() ?? '');
    final manufacturingPriceCtrl = TextEditingController(
        text: (goal['manufacturing_price_g'] as num?) != null &&
                (goal['manufacturing_price_g'] as num) > 0
            ? (goal['manufacturing_price_g'] as num).toString()
            : '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(AppStrings.t(ctx, 'edit')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: goalKarat,
                  decoration: InputDecoration(
                      labelText: AppStrings.t(context, 'karat')),
                  items: _karatOptions
                      .map((k) => DropdownMenuItem(
                          value: k, child: Text(_karatLabelFromKey(k))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => goalKarat = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: targetWeight,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: InputDecoration(
                      labelText: AppStrings.t(ctx, 'target_weight')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: manufacturingPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: InputDecoration(
                    labelText: AppStrings.t(ctx, 'manufacturing_price'),
                    hintText: '0.00',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppStrings.t(ctx, 'cancel'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppStrings.t(ctx, 'save'))),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await _safeAction(() async {
      await widget.apiService.updateGoal(
        goalId: goal['id'] as int,
        karat: goalKarat,
        targetWeightG: double.tryParse(targetWeight.text) ?? 0,
        savedAmount: (goal['saved_amount'] as num?)?.toDouble() ?? 0,
        manufacturingPriceG:
            double.tryParse(manufacturingPriceCtrl.text) ?? 0,
      );
      await _load();
    });
  }

  /// Creates a goal directly with a fixed [targetPrice] from the calculator.
  Future<void> _addGoalFromCalc({
    required double targetPrice,
    required String karat,
    required double weightG,
    required double manufacturingPriceG,
  }) async {
    if (_selectedMemberId == null) return;
    await _safeAction(() async {
      await widget.apiService.createGoal(
        memberId: _selectedMemberId!,
        karat: karat,
        targetWeightG: weightG,
        savedAmount: 0,
        manufacturingPriceG: manufacturingPriceG,
        overrideTargetPrice: targetPrice,
      );
      await _load();
    });
  }

  Future<void> _deleteGoalConfirm(Map<String, dynamic> goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t(ctx, 'confirm_delete')),
        content: Text(
            '${_karatLabelFromKey('${goal['karat']}')} · ${goal['target_weight_g']}g'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.t(ctx, 'cancel'))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.t(ctx, 'delete'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _safeAction(() async {
      await widget.apiService.deleteGoal(goal['id'] as int);
      await _load();
    });
  }

  Future<void> _addCompanyDialog() async {
    final name = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.t(context, 'add_company')),
        content: TextField(
            controller: name,
            decoration: InputDecoration(
                labelText: AppStrings.t(context, 'company_name'))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.t(context, 'cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.t(context, 'save'))),
        ],
      ),
    );
    if (saved == true && name.text.trim().isNotEmpty) {
      await _safeAction(() async {
        await widget.apiService.addCompany(name.text.trim());
        await _load();
      });
    }
  }

  Map<String, dynamic>? _priceFor(String karat) {
    if (_prices == null) return null;
    final prices = _prices!['prices'] as Map<String, dynamic>? ?? {};
    return prices[karat] as Map<String, dynamic>?;
  }

  Widget _priceCard({
    required String label,
    required String karat,
    bool isHero = false,
    double? width,
    List<Color>? gradientColors,
    String? currencyOverride,
  }) {
    final data = _priceFor(karat);
    final buy = data != null ? _currency.format(data['buy_price']) : '—';
    final sell = data != null ? _currency.format(data['sell_price']) : '—';
    final currency = currencyOverride ?? data?['currency']?.toString() ?? 'EGP';

    final height = isHero ? 150.0 : 120.0;
    final labelSize = isHero ? 13.0 : 11.5;
    final priceSize = isHero ? 32.0 : 22.0;
    final subSize = isHero ? 12.0 : 11.0;

    final colors = gradientColors ??
        (isHero
            ? const [
                Color(0xFFE8CD5A),
                Color(0xFFD4B254),
                Color(0xFFB5973F),
                Color(0xFF8B7332)
              ]
            : const [Color(0xFFD4B254), Color(0xFFC19A3E), Color(0xFF9E8030)]);

    final glowColor = (gradientColors?.first ?? const Color(0xFFD4B254))
        .withValues(alpha: 0.35);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: isHero ? 24 : 16,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
          horizontal: isHero ? 20 : 16, vertical: isHero ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$sell',
                style: TextStyle(
                  fontSize: priceSize,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currency,
                style: TextStyle(
                  fontSize: subSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Flexible(child: _priceChip(buy, subSize)),
              const SizedBox(width: 6),
              Flexible(child: _priceChip(sell, subSize)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceChip(String value, double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  Widget _gapInfoCard() {
    final data24k = _priceFor('24k');
    final dataOunce = _priceFor('ounce');
    if (data24k == null || dataOunce == null) return const SizedBox.shrink();

    final local24kSell = (data24k['sell_price'] as num?)?.toDouble() ?? 0;
    final ounceUsd = (dataOunce['sell_price'] as num?)?.toDouble() ?? 0;
    if (ounceUsd <= 0 || local24kSell <= 0) return const SizedBox.shrink();

    final global24kGramUsd = ounceUsd / 31.1035;
    final jewellerDollar = local24kSell / global24kGramUsd;

    final officialRate = _usdEgpRate;
    double? egpDiff;
    double? premiumPct;
    bool isExpensive = false;
    if (officialRate != null && officialRate > 0) {
      final global24kInEgp = global24kGramUsd * officialRate;
      egpDiff = local24kSell - global24kInEgp;
      premiumPct = ((jewellerDollar - officialRate) / officialRate) * 100;
      isExpensive = premiumPct > 0;
    }

    final gapColor = premiumPct != null
        ? (isExpensive ? const Color(0xFFD32F2F) : const Color(0xFF388E3C))
        : Theme.of(context).colorScheme.onSurface;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? gapColor.withValues(alpha: 0.15)
        : gapColor.withValues(alpha: 0.08);
    final cardBorder = gapColor.withValues(alpha: isDark ? 0.3 : 0.2);

    return GestureDetector(
      onTap: () => _showGapExplanation(
          jewellerDollar, officialRate, premiumPct, egpDiff),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: gapColor.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        AppStrings.t(context, 'jeweller_dollar'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: gapColor.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: gapColor.withValues(alpha: 0.45)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    jewellerDollar.toStringAsFixed(2),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: gapColor.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            if (egpDiff != null)
              Text(
                '${egpDiff >= 0 ? '+' : ''}${_currency.format(egpDiff)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: gapColor,
                  letterSpacing: -0.5,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (premiumPct != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: gapColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${premiumPct >= 0 ? '+' : ''}${premiumPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: gapColor),
                      ),
                    ),
                  if (officialRate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${AppStrings.t(context, 'official_rate')}: ${officialRate.toStringAsFixed(1)}',
                      style: TextStyle(
                          fontSize: 10, color: gapColor.withValues(alpha: 0.6)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGapExplanation(double jewellerDollar, double? officialRate,
      double? premiumPct, double? egpDiff) {
    final isAr = widget.locale.languageCode == 'ar';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            isAr ? 'ما هو دولار الصاغة؟' : "What is the Jeweler's Dollar?"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAr
                    ? 'دولار الصاغة هو سعر الدولار الضمني المشتق من أسعار الذهب المحلية مقارنة بالسعر العالمي.'
                    : "The Jeweler's Dollar is the implied USD/EGP exchange rate derived from local gold prices versus the global gold price.",
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              Text(
                isAr ? 'طريقة الحساب:' : 'How it\'s calculated:',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _explanationRow(
                isAr ? 'سعر الأونصة العالمي' : 'Global ounce price',
                '${_priceFor('ounce')?['sell_price'] ?? '—'} USD',
              ),
              _explanationRow(
                isAr
                    ? 'سعر الجرام العالمي (÷ 31.1)'
                    : 'Global gram price (÷ 31.1)',
                '${(_priceFor('ounce')?['sell_price'] as num? ?? 0).toDouble() > 0 ? ((_priceFor('ounce')!['sell_price'] as num).toDouble() / 31.1035).toStringAsFixed(2) : '—'} USD',
              ),
              _explanationRow(
                isAr ? 'سعر 24 قيراط المحلي' : 'Local 24K sell price',
                '${_priceFor('24k')?['sell_price'] ?? '—'} EGP',
              ),
              const Divider(height: 20),
              _explanationRow(
                isAr
                    ? 'دولار الصاغة = محلي ÷ عالمي'
                    : "Jeweler's \$ = local ÷ global",
                jewellerDollar.toStringAsFixed(2),
                isBold: true,
              ),
              if (officialRate != null) ...[
                _explanationRow(
                  isAr ? 'السعر الرسمي' : 'Official rate',
                  officialRate.toStringAsFixed(2),
                ),
                if (premiumPct != null)
                  _explanationRow(
                    isAr ? 'الفرق (علاوة/خصم)' : 'Gap (premium/discount)',
                    '${premiumPct >= 0 ? '+' : ''}${premiumPct.toStringAsFixed(1)}%',
                    valueColor: premiumPct > 0
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF388E3C),
                    isBold: true,
                  ),
              ],
              const SizedBox(height: 12),
              Text(
                isAr
                    ? 'إذا كان دولار الصاغة أعلى من السعر الرسمي، فالذهب المحلي به علاوة سعرية. إذا أقل، فالذهب المحلي أرخص نسبياً.'
                    : 'If the jeweler\'s dollar is above the official rate, local gold carries a premium. If below, local gold is relatively cheaper.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'حسناً' : 'Got it'),
          ),
        ],
      ),
    );
  }

  Widget _explanationRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _poundCard() {
    return _priceCard(
      label: widget.locale.languageCode == 'ar' ? 'جنيه ذهب' : 'Gold Pound',
      karat: 'gold_pound_8g',
      gradientColors: const [
        Color(0xFFD4B254),
        Color(0xFFBE9A40),
        Color(0xFF9E7E2C)
      ],
    );
  }

  Widget _ounceCard() {
    return _priceCard(
      label:
          widget.locale.languageCode == 'ar' ? 'أونصة عالمية' : 'Global Ounce',
      karat: 'ounce',
      currencyOverride: 'USD',
      gradientColors: const [
        Color(0xFFE0C45C),
        Color(0xFFCCAE3A),
        Color(0xFFAA9028)
      ],
    );
  }

  Widget _livePricesHeader(String timeLabel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldAccent =
        isDark ? const Color(0xFFD4B254) : const Color(0xFFB5973F);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  goldAccent.withValues(alpha: 0.18),
                  goldAccent.withValues(alpha: 0.06)
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.show_chart_rounded, size: 20, color: goldAccent),
          ),
          const SizedBox(width: 12),
          Text(
            AppStrings.t(context, 'live_prices'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: goldAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time_rounded, size: 12, color: goldAccent),
                const SizedBox(width: 4),
                Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: goldAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: goldAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: _busy
                  ? null
                  : () => _safeAction(() async {
                        await widget.apiService.syncPrices();
                        await _load();
                      }),
              icon: Icon(Icons.refresh_rounded, size: 18, color: goldAccent),
              tooltip: AppStrings.t(context, 'sync_prices'),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceCardForKey(String key) {
    switch (key) {
      case '21k':
        return _priceCard(
            label: _karatLabelFromKey('21k'), karat: '21k', isHero: true);
      case '24k':
        return _priceCard(
            label: _karatLabelFromKey('24k'), karat: '24k', isHero: true);
      case '14k_18k':
        return Row(
          children: [
            Expanded(
                child: _priceCard(
                    label: _karatLabelFromKey('14k'), karat: '14k')),
            const SizedBox(width: 8),
            Expanded(
                child: _priceCard(
                    label: _karatLabelFromKey('18k'), karat: '18k')),
          ],
        );
      case 'pound_ounce':
        return Row(
          children: [
            Expanded(child: _poundCard()),
            const SizedBox(width: 8),
            Expanded(child: _ounceCard()),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _overviewTab() {
    final updatedAt = _prices?['updated_at']?.toString() ?? '';
    String timeLabel = '—';
    if (updatedAt.isNotEmpty) {
      final parsed = DateTime.tryParse(updatedAt);
      if (parsed != null) {
        final local = parsed.toLocal();
        timeLabel =
            '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _livePricesHeader(timeLabel)),
        SliverReorderableList(
          itemCount: _priceCardOrder.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _priceCardOrder.removeAt(oldIndex);
              _priceCardOrder.insert(newIndex, item);
            });
            _saveCardOrder();
          },
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(animation.value);
                final elevation = lerpDouble(0, 12, t)!;
                final scale = lerpDouble(1, 1.04, t)!;
                return Transform.scale(
                  scale: scale,
                  child: Material(
                    elevation: elevation,
                    color: Colors.transparent,
                    shadowColor: const Color(0xFFD4B254).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },
          itemBuilder: (context, index) {
            final key = _priceCardOrder[index];
            return ReorderableDelayedDragStartListener(
              key: ValueKey(key),
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _priceCardForKey(key),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(child: _gapInfoCard()),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (_summary != null)
          SliverToBoxAdapter(
            child: _sectionCard(
              title: AppStrings.t(context, 'asset_summary'),
              child: Column(
                children: [
                  _totalRow(AppStrings.t(context, 'current_value'),
                      '${_currency.format(_summary!['summary']['current_value'])} EGP'),
                  const SizedBox(height: 4),
                  _totalRow(AppStrings.t(context, 'purchase_cost'),
                      '${_currency.format(_summary!['summary']['purchase_cost'])} EGP'),
                  const SizedBox(height: 4),
                  _totalRow(
                    AppStrings.t(context, 'profit_loss'),
                    '${(_summary!['summary']['profit_loss'] as num) >= 0 ? '+' : ''}${_currency.format(_summary!['summary']['profit_loss'])} EGP',
                    valueColor:
                        (_summary!['summary']['profit_loss'] as num) >= 0
                            ? const Color(0xFF388E3C)
                            : const Color(0xFFD32F2F),
                  ),
                  const SizedBox(height: 4),
                  _totalRow(AppStrings.t(context, 'equivalent_21k'),
                      '${_currency.format(_summary!['summary']['total_weight_21k_equivalent'] ?? 0)} g'),
                  const SizedBox(height: 4),
                  _totalRow(AppStrings.t(context, 'equivalent_24k'),
                      '${_currency.format(_summary!['summary']['total_weight_24k_equivalent'])} g'),
                ],
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (_zakat != null)
          SliverToBoxAdapter(
            child: _sectionCard(
              title: AppStrings.t(context, 'zakat'),
              child: Column(
                children: [
                  _totalRow(
                      AppStrings.t(context, 'eligible'),
                      _zakat!['zakat']['eligible'] == true
                          ? AppStrings.t(context, 'yes')
                          : AppStrings.t(context, 'no')),
                  const SizedBox(height: 4),
                  _totalRow(AppStrings.t(context, 'zakat_due'),
                      '${_currency.format(_zakat!['zakat']['zakat_due'])} EGP'),
                  const SizedBox(height: 4),
                  _totalRow(
                    AppStrings.t(context, 'threshold_current'),
                    '${_zakat!['zakat']['threshold_weight_24k']}g / '
                    '${_currency.format(_zakat!['total_weight_24k_equivalent'])}g',
                  ),
                ],
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  static int _karatNumber(String karat) {
    final match = RegExp(r'\d+').firstMatch(karat);
    return match != null ? int.parse(match.group(0)!) : 24;
  }

  /// Renders a karat key (e.g. "21k", "24k") in the user's locale.
  ///   en -> "21K", "24K"
  ///   ar -> "عيار 21", "عيار 24"
  /// Numbers stay in Western digits in both modes (product decision).
  String _karatLabelFromKey(String karatKey) {
    return AppStrings.formatKarat(
        widget.locale.languageCode, _karatNumber(karatKey));
  }

  Map<String, double> _gramsByKarat() {
    final map = <String, double>{};
    for (final asset in _assets) {
      final karat = asset['karat']?.toString() ?? '?';
      final weight = (asset['weight_g'] as num?)?.toDouble() ?? 0;
      map[karat] = (map[karat] ?? 0) + weight;
    }
    return map;
  }

  double _totalIn21k() {
    double total = 0;
    for (final asset in _assets) {
      final karat = asset['karat']?.toString() ?? '21k';
      final weight = (asset['weight_g'] as num?)?.toDouble() ?? 0;
      total += weight * _karatNumber(karat) / 21;
    }
    return total;
  }

  double _currentValueForAsset(Map<String, dynamic> asset) {
    if (_prices == null) return 0;
    final pricesMap = _prices!['prices'] as Map<String, dynamic>? ?? {};
    final karat = asset['karat']?.toString() ?? '';
    final priceData = pricesMap[karat] as Map<String, dynamic>?;
    if (priceData == null) return 0;
    final buyPrice = (priceData['buy_price'] as num?)?.toDouble() ?? 0;
    final weight = (asset['weight_g'] as num?)?.toDouble() ?? 0;
    return buyPrice * weight;
  }

  double _getBuyPriceForKarat(String karat) {
    if (_prices == null) return 0;
    final pricesMap = _prices!['prices'] as Map<String, dynamic>? ?? {};
    final priceData = pricesMap[karat] as Map<String, dynamic>?;
    if (priceData == null) return 0;
    return (priceData['buy_price'] as num?)?.toDouble() ?? 0;
  }

  Map<String, double> _calcResults() {
    final weight = double.tryParse(_calcWeightCtrl.text) ?? 0;
    final mfg = double.tryParse(_calcMfgCtrl.text) ?? 0;
    final taxPerGram = double.tryParse(_calcTaxCtrl.text) ?? 10;
    final pricePerGram = _getBuyPriceForKarat(_calcKarat);
    final goldValue = pricePerGram * weight;
    final mfgCost = mfg * weight;
    final tax = taxPerGram * weight;
    return {
      'gold_value': goldValue,
      'mfg_cost': mfgCost,
      'tax': tax,
      'without_adds': goldValue,
      'total_adds': mfgCost + tax,
      'with_adds': goldValue + mfgCost + tax,
    };
  }

  Widget _goldCalculatorPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldAccent =
        isDark ? const Color(0xFFD4B254) : const Color(0xFFB5973F);
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1C1916), Color(0xFF1A1816), Color(0xFF181614)],
              )
            : null,
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: goldAccent.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: goldAccent.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _calcExpanded,
          onExpansionChanged: (v) => setState(() => _calcExpanded = v),
          leading: Icon(Icons.calculate_outlined,
              color: goldAccent, size: 22),
          title: Text(
            AppStrings.t(context, 'gold_calculator'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: goldAccent,
            ),
          ),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            StatefulBuilder(
              builder: (ctx, setCalcState) {
                final results = _calcResults();
                final weight =
                    double.tryParse(_calcWeightCtrl.text) ?? 0;
                final hasWeight = weight > 0;

                void recalc() => setCalcState(() {});

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Karat + Weight
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _calcKarat,
                            decoration: InputDecoration(
                              labelText: AppStrings.t(context, 'karat'),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            items: _karatOptions
                                .map((k) => DropdownMenuItem(
                                    value: k,
                                    child: Text(_karatLabelFromKey(k))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _calcKarat = v);
                                recalc();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _calcWeightCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: InputDecoration(
                              labelText: AppStrings.t(context, 'weight_g'),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onChanged: (_) => recalc(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 2: Manufacturing + Tax
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _calcMfgCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: InputDecoration(
                              labelText:
                                  AppStrings.t(context, 'manufacturing_price'),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onChanged: (_) => recalc(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _calcTaxCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: InputDecoration(
                              labelText:
                                  AppStrings.t(context, 'tax_tariff_pct'),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              suffixText: 'EGP',
                            ),
                            onChanged: (_) => recalc(),
                          ),
                        ),
                      ],
                    ),
                    if (hasWeight) ...[
                      const SizedBox(height: 14),
                      // Results
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: goldAccent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: goldAccent.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          children: [
                            _calcResultRow(
                              label: AppStrings.t(
                                  context, 'price_without_adds'),
                              value: results['without_adds']!,
                              color: cs.onSurface,
                              bold: false,
                            ),
                            const Divider(height: 12),
                            _calcResultRow(
                              label: AppStrings.t(
                                  context, 'total_adds'),
                              value: results['total_adds']!,
                              color: cs.onSurfaceVariant,
                              bold: false,
                            ),
                            const Divider(height: 12),
                            _calcResultRow(
                              label: AppStrings.t(
                                  context, 'price_with_adds'),
                              value: results['with_adds']!,
                              color: goldAccent,
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedMemberId != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: Text(
                                AppStrings.t(context, 'add_to_goals')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: goldAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _busy
                                ? null
                                : () async {
                                    final withoutAdds =
                                        results['without_adds']!;
                                    final withAdds = results['with_adds']!;
                                    final chosen =
                                        await showDialog<double>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(AppStrings.t(
                                            context, 'choose_goal_price')),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              title: Text(AppStrings.t(
                                                  context,
                                                  'price_without_adds')),
                                              subtitle: Text(
                                                  '${_currency.format(withoutAdds)} EGP'),
                                              onTap: () =>
                                                  Navigator.pop(
                                                      ctx, withoutAdds),
                                            ),
                                            ListTile(
                                              title: Text(AppStrings.t(
                                                  context,
                                                  'price_with_adds')),
                                              subtitle: Text(
                                                  '${_currency.format(withAdds)} EGP'),
                                              onTap: () =>
                                                  Navigator.pop(
                                                      ctx, withAdds),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx),
                                            child: Text(AppStrings.t(
                                                context, 'cancel')),
                                          )
                                        ],
                                      ),
                                    );
                                    if (chosen == null) return;
                                    await _addGoalFromCalc(
                                      targetPrice: chosen,
                                      karat: _calcKarat,
                                      weightG: weight,
                                      manufacturingPriceG:
                                          double.tryParse(
                                                  _calcMfgCtrl.text) ??
                                              0,
                                    );
                                  },
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _calcResultRow({
    required String label,
    required double value,
    required Color color,
    required bool bold,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          '${_currency.format(value)} EGP',
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _assetsTotalsCard() {
    if (_assets.isEmpty) return const SizedBox.shrink();

    double totalCurrentValue = 0;
    double totalPurchaseCost = 0;
    for (final asset in _assets) {
      totalCurrentValue += _currentValueForAsset(asset as Map<String, dynamic>);
      totalPurchaseCost += (asset['purchase_price'] as num?)?.toDouble() ?? 0;
    }
    final profitLoss = totalCurrentValue - totalPurchaseCost;
    final gramsByKarat = _gramsByKarat();
    final isPricesAvailable = _prices != null;

    return _sectionCard(
      title: AppStrings.t(context, 'portfolio_totals'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPricesAvailable) ...[
            _totalRow(AppStrings.t(context, 'current_value'),
                '${_currency.format(totalCurrentValue)} EGP'),
            _totalRow(AppStrings.t(context, 'purchase_cost'),
                '${_currency.format(totalPurchaseCost)} EGP'),
            _totalRow(
              AppStrings.t(context, 'profit_loss'),
              '${profitLoss >= 0 ? '+' : ''}${_currency.format(profitLoss)} EGP',
              valueColor: profitLoss >= 0 ? Colors.green : Colors.red,
            ),
            if (totalPurchaseCost > 0)
              _totalRow(
                AppStrings.t(context, 'return_pct'),
                '${(profitLoss / totalPurchaseCost * 100).toStringAsFixed(1)}%',
                valueColor: profitLoss >= 0 ? Colors.green : Colors.red,
              ),
          ] else
            Text(AppStrings.t(context, 'prices_unavailable')),
          _thinDivider(),
          Text(
            AppStrings.t(context, 'weight_by_karat'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          ...gramsByKarat.entries.map(
            (e) => _totalRow(
                _karatLabelFromKey(e.key), '${_currency.format(e.value)} g'),
          ),
          _thinDivider(),
          _totalRow(
            AppStrings.t(context, 'total_all_21k'),
            '${_currency.format(_totalIn21k())} g',
          ),
        ],
      ),
    );
  }

  Widget _thinDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldAccent =
        isDark ? const Color(0xFFD4B254) : const Color(0xFFB5973F);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
        height: 0.5,
        thickness: 0.5,
        color: goldAccent.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _totalRow(String label, String value, {Color? valueColor}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: valueColor ?? cs.onSurface,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  String _assetTypeLabel(String type) {
    return AppStrings.t(context, type);
  }

  static const _assetImageMap = {
    'ring': 'assets/icons/ring.png',
    'necklace': 'assets/icons/necklace.png',
    'bracelet': 'assets/icons/bracelet.png',
    'coins': 'assets/icons/coin.png',
    'ingot': 'assets/icons/ingot.png',
  };

  static const _assetIconData = <String, IconData>{
    'ring': Icons.circle_outlined,
    'necklace': Icons.auto_awesome,
    'bracelet': Icons.panorama_fish_eye,
    'coins': Icons.paid_outlined,
    'ingot': Icons.account_balance_outlined,
    'other': Icons.diamond_outlined,
  };

  Widget _assetCircleIcon(String type, {double size = 48, double? weightG}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldAccent =
        isDark ? const Color(0xFFD4B254) : const Color(0xFFB5973F);
    final assetPath = _assetImageMap[type];
    final showWeight = weightG != null && (type == 'ingot' || type == 'coins');

    Widget icon;
    if (assetPath != null) {
      icon = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: goldAccent.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(assetPath, fit: BoxFit.cover),
        ),
      );
    } else {
      icon = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              goldAccent.withValues(alpha: 0.2),
              goldAccent.withValues(alpha: 0.06),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: goldAccent.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          _assetIconData[type] ?? Icons.diamond_outlined,
          size: size * 0.45,
          color: goldAccent,
        ),
      );
    }

    if (!showWeight) return icon;

    final weightLabel = weightG! % 1 == 0
        ? '${weightG.toInt()}g'
        : '${weightG.toStringAsFixed(1)}g';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            bottom: -2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2210) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: goldAccent.withValues(alpha: 0.5), width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  weightLabel,
                  style: TextStyle(
                    fontSize: size * 0.2,
                    fontWeight: FontWeight.w800,
                    color: goldAccent,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetCard(Map<String, dynamic> asset) {
    final type = asset['asset_type']?.toString() ?? 'jewellery';
    final currentVal = _currentValueForAsset(asset);
    final purchaseVal = (asset['purchase_price'] as num?)?.toDouble() ?? 0;
    final assetPL = currentVal - purchaseVal;
    final plPct = purchaseVal > 0 ? (assetPL / purchaseVal * 100) : 0.0;
    final invPath = asset['invoice_local_path']?.toString();
    final purchaseDate = asset['purchase_date']?.toString() ?? '';
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final goldAccent =
        isDark ? const Color(0xFFD4B254) : const Color(0xFFB5973F);
    final plColor =
        assetPL >= 0 ? const Color(0xFF388E3C) : const Color(0xFFD32F2F);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B16) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: goldAccent.withValues(alpha: isDark ? 0.1 : 0.06),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : goldAccent.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _assetCircleIcon(type,
                    size: 48, weightG: (asset['weight_g'] as num?)?.toDouble()),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _assetTypeLabel(type),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: goldAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _karatLabelFromKey('${asset['karat']}'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: goldAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${asset['weight_g']}g${purchaseDate.isNotEmpty ? '  ·  $purchaseDate' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (invPath != null && invPath.isNotEmpty && !kIsWeb)
                  IconButton(
                    onPressed: () => OpenFilex.open(invPath),
                    icon: Icon(Icons.receipt_long_outlined,
                        size: 18, color: cs.onSurfaceVariant),
                    tooltip: AppStrings.t(context, 'open_invoice'),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                IconButton(
                  onPressed: () => _addAssetDialog(existing: asset),
                  icon: Icon(Icons.edit_outlined,
                      size: 18, color: cs.onSurfaceVariant),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title:
                                  Text(AppStrings.t(context, 'confirm_delete')),
                              content: Text(
                                  AppStrings.t(context, 'confirm_delete_msg')),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child:
                                        Text(AppStrings.t(context, 'cancel'))),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(AppStrings.t(context, 'delete'),
                                      style:
                                          const TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _safeAction(() async {
                              await widget.apiService
                                  .deleteAsset(asset['id'] as int);
                              await _load();
                            });
                          }
                        },
                  icon: Icon(Icons.delete_outline,
                      size: 18,
                      color: const Color(0xFFD32F2F).withValues(alpha: 0.7)),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (_prices != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF252118)
                      : const Color(0xFFFAF7F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _assetDetailRow(
                      AppStrings.t(context, 'purchased'),
                      '${_currency.format(purchaseVal)} EGP',
                    ),
                    const SizedBox(height: 8),
                    _assetDetailRow(
                      AppStrings.t(context, 'now'),
                      '${_currency.format(currentVal)} EGP',
                      valueColor: const Color(0xFF388E3C),
                    ),
                    const SizedBox(height: 10),
                    Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: goldAccent.withValues(alpha: 0.1)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: plColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                assetPL >= 0
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                size: 16,
                                color: plColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${assetPL >= 0 ? '+' : ''}${plPct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: plColor),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${assetPL >= 0 ? '+' : ''}${_currency.format(assetPL)} EGP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: plColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              _assetDetailRow(
                AppStrings.t(context, 'purchased'),
                '${_currency.format(purchaseVal)} EGP',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assetDetailRow(String label, String value, {Color? valueColor}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor ?? cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _assetsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldAccent =
        isDark ? const Color(0xFFD4B254) : const Color(0xFFB5973F);
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _assetsTotalsCard(),
        if (_assets.isNotEmpty) const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(
                '${AppStrings.t(context, 'assets_count')} (${_assets.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: goldAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: _selectedMemberId == null || _busy
                      ? null
                      : () => _addAssetDialog(),
                  icon: Icon(Icons.add_rounded, size: 20, color: goldAccent),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
        if (_assets.isEmpty)
          _emptyStateWidget(
            icon: Icons.workspace_premium_outlined,
            title: AppStrings.t(context, 'no_data'),
            subtitle: widget.locale.languageCode == 'ar'
                ? 'أضف أول قطعة ذهب لتتبع محفظتك'
                : 'Add your first gold piece to track your portfolio',
            onAction: _selectedMemberId == null || _busy
                ? null
                : () => _addAssetDialog(),
            actionLabel: AppStrings.t(context, 'add_asset'),
          )
        else
          ..._assets.map((asset) => _assetCard(asset as Map<String, dynamic>)),
      ],
    );
  }

  Widget _savingsGoalsTab() {
    return ListView(
      children: [
        _sectionCard(
          title: AppStrings.t(context, 'savings'),
          actions: [
            IconButton(
              onPressed:
                  _selectedMemberId == null || _busy ? null : _addSavingDialog,
              icon: const Icon(Icons.add),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final goldAccent =
                    isDark ? const Color(0xFFD4B254) : const Color(0xFFB5973F);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        goldAccent.withValues(alpha: 0.12),
                        goldAccent.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: goldAccent.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: goldAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.account_balance_wallet,
                            size: 20, color: goldAccent),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t(context, 'total_saved'),
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_currency.format(_totalSaved)} EGP',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              if (_savingEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    AppStrings.t(context, 'no_data'),
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ..._savingEntries.map((entry) {
                final targetType = entry['target_type']?.toString();
                final targetKarat = entry['target_karat']?.toString();
                final targetKaratLabel = (targetKarat == null || targetKarat.isEmpty)
                    ? ''
                    : _karatLabelFromKey(targetKarat);
                final targetLabel = targetType != null
                    ? '${_assetTypeLabel(targetType)} $targetKaratLabel'.trim()
                    : '';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: targetType != null
                      ? _assetCircleIcon(targetType, size: 28)
                      : null,
                  title: Text(
                      '${_currency.format(entry['amount'])} ${entry['currency']}'),
                  subtitle: Text(
                    '${entry['created_at']}${targetLabel.isNotEmpty ? '  •  ${AppStrings.t(context, 'target')}: $targetLabel' : ''}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: _busy
                        ? null
                        : () =>
                            _editSavingDialog(entry as Map<String, dynamic>),
                    tooltip: AppStrings.t(context, 'edit'),
                  ),
                  onTap: _busy
                      ? null
                      : () => _editSavingDialog(entry as Map<String, dynamic>),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _goldCalculatorPanel(),
        _sectionCard(
          title: AppStrings.t(context, 'goals'),
          actions: [
            IconButton(
              onPressed:
                  _selectedMemberId == null || _busy ? null : _addGoalDialog,
              icon: const Icon(Icons.add),
            ),
          ],
          child: _goals.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    AppStrings.t(context, 'no_data'),
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                )
              : Column(
                  children: _goals.map((goal) {
                    final target =
                        (goal['target_price'] as num?)?.toDouble() ?? 0;
                    final saved = _totalSaved;
                    final remaining =
                        (target - saved).clamp(0.0, double.infinity);
                    final progress =
                        target > 0 ? (saved / target).clamp(0, 1) : 0.0;
                    final pct = (progress * 100).toStringAsFixed(0);
                    final cs = Theme.of(context).colorScheme;
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final goldAccent = isDark
                        ? const Color(0xFFD4B254)
                        : const Color(0xFFB5973F);
                    final progressColor =
                        progress >= 1.0 ? const Color(0xFF388E3C) : goldAccent;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF252118)
                            : const Color(0xFFFAF7F0),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: goldAccent.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: goldAccent.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_karatLabelFromKey('${goal['karat']}')} · ${goal['target_weight_g']}g',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _editGoalDialog(
                                    goal as Map<String, dynamic>),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.edit_outlined,
                                      size: 14, color: cs.onSurfaceVariant),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _deleteGoalConfirm(
                                    goal as Map<String, dynamic>),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: cs.error.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.delete_outline,
                                      size: 14, color: cs.error),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${AppStrings.t(context, 'remaining')}: ${_currency.format(remaining)} EGP',
                                  style: TextStyle(
                                      fontSize: 12, color: cs.onSurfaceVariant),
                                ),
                              ),
                              Text(
                                '$pct%',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: progressColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress.toDouble(),
                              minHeight: 8,
                              backgroundColor:
                                  progressColor.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation(progressColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _companiesSettingsTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _sectionCard(
          title: AppStrings.t(context, 'companies'),
          actions: [
            IconButton(
                onPressed: _busy ? null : _addCompanyDialog,
                icon: const Icon(Icons.add_business)),
          ],
          child: _companies.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    AppStrings.t(context, 'no_data'),
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _companies
                      .map((company) =>
                          Chip(label: Text(company['name'].toString())))
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: AppStrings.t(context, 'settings'),
          child: Column(
            children: [
              _settingsRow(
                icon: Icons.dark_mode_outlined,
                title: AppStrings.t(context, 'dark_mode'),
                trailing: Semantics(
                  toggled: widget.themeMode == ThemeMode.dark,
                  label: 'Dark mode',
                  excludeSemantics: true,
                  child: Switch.adaptive(
                    value: widget.themeMode == ThemeMode.dark,
                    onChanged: (isDark) {
                      widget.onThemeChanged(isDark);
                      _persistSettings();
                    },
                  ),
                ),
              ),
              Divider(
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.15)),
              _settingsRow(
                icon: Icons.language_outlined,
                title: AppStrings.t(context, 'language'),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('EN')),
                    ButtonSegment(value: 'ar', label: Text('ع')),
                  ],
                  selected: {widget.locale.languageCode},
                  onSelectionChanged: (value) {
                    widget.onLocaleChanged(Locale(value.first));
                    _persistSettings();
                  },
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              if (!kIsWeb && widget.pushNotificationsService != null) ...[
                Divider(
                    height: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.15)),
                _PushSummariesRow(
                  pushService: widget.pushNotificationsService!,
                  apiService: widget.apiService,
                  buildSettingsRow: _settingsRow,
                ),
                
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _backupRestoreCard(),
      ],
    );
  }

  Widget _settingsRow(
      {required IconData icon,
      required String title,
      required Widget trailing}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final goldAccent =
        isDark ? const Color(0xFFD4B254) : const Color(0xFFB5973F);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: goldAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: goldAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  /// Shows a dialog that lets the user navigate Google Drive folders and pick
  /// one to upload the backup into. Returns the chosen folder ID, or null if
  /// the user cancelled or the API failed.
  Future<String?> _pickDriveFolder() async {
    final driveService = GoogleDriveService();
    final isAr = widget.locale.languageCode == 'ar';

    // Stack for navigation: each entry is (parentId, folderName).
    final nav = <(String?, String)>[(null, isAr ? 'My Drive' : 'My Drive')];
    List<DriveFolder>? folders;

    try {
      folders = await driveService.listFolders();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAr
              ? 'فشل الاتصال بـ Google Drive'
              : 'Could not connect to Google Drive'),
        ));
      }
      return null;
    }
    if (folders == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAr
              ? 'تأكد من تسجيل الدخول بحساب Google'
              : 'Sign in with Google first'),
        ));
      }
      return null;
    }

    if (!mounted) return null;

    return showDialog<String?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            final current = nav.last;
            final currentId = current.$1;
            final currentName = current.$2;
            final loading = folders == null;

            return AlertDialog(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  if (nav.length > 1)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      onPressed: () async {
                        nav.removeLast();
                        setDlgState(() => folders = null);
                        final parentId = nav.last.$1;
                        try {
                          final f = await driveService.listFolders(
                              parentId: parentId);
                          setDlgState(() => folders = f ?? []);
                        } catch (_) {
                          setDlgState(() => folders = []);
                        }
                      },
                    ),
                  Expanded(
                    child: Text(
                      currentName,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.create_new_folder_outlined,
                        size: 20),
                    tooltip: isAr ? 'مجلد جديد' : 'New folder',
                    onPressed: () async {
                      final nameCtrl = TextEditingController();
                      final name = await showDialog<String>(
                        context: ctx,
                        builder: (c2) => AlertDialog(
                          title: Text(
                              isAr ? 'مجلد جديد' : 'New folder'),
                          content: TextField(
                            controller: nameCtrl,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: isAr
                                  ? 'اسم المجلد'
                                  : 'Folder name',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c2),
                              child: Text(isAr ? 'إلغاء' : 'Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(c2, nameCtrl.text.trim()),
                              child: Text(isAr ? 'إنشاء' : 'Create'),
                            ),
                          ],
                        ),
                      );
                      if (name != null && name.isNotEmpty) {
                        setDlgState(() => folders = null);
                        final created = await driveService.createFolder(
                            name,
                            parentId: currentId);
                        if (created != null) {
                          try {
                            final f = await driveService.listFolders(
                                parentId: currentId);
                            setDlgState(() => folders = f ?? []);
                          } catch (_) {
                            setDlgState(() => folders = []);
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : folders!.isEmpty
                        ? Center(
                            child: Text(
                              isAr ? 'لا توجد مجلدات' : 'No folders',
                              style: TextStyle(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            itemCount: folders!.length,
                            itemBuilder: (_, i) {
                              final f = folders![i];
                              return ListTile(
                                leading: Icon(Icons.folder,
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .primary),
                                title: Text(f.name),
                                trailing: const Icon(
                                    Icons.chevron_right,
                                    size: 18),
                                onTap: () async {
                                  nav.add((f.id, f.name));
                                  setDlgState(() => folders = null);
                                  try {
                                    final sub =
                                        await driveService.listFolders(
                                            parentId: f.id);
                                    setDlgState(
                                        () => folders = sub ?? []);
                                  } catch (_) {
                                    setDlgState(() => folders = []);
                                  }
                                },
                              );
                            },
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text(isAr ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: Text(isAr ? 'رفع هنا' : 'Upload here'),
                  onPressed: () =>
                      Navigator.pop(ctx, currentId ?? '__root__'),
                ),
              ],
            );
          },
        );
      },
    ).then((v) => v == '__root__' ? null : v);
  }

  Widget _backupRestoreCard() {
    return _sectionCard(
      title: AppStrings.t(context, 'backup_restore'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                AppStrings.t(context, 'backup_web_hint'),
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.save_alt_outlined),
            title: Text(AppStrings.t(context, 'export_backup')),
            trailing: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _busy
                ? null
                : () => _safeAction(() async {
                      final backupService = BackupService();
                      final userId =
                          widget.authService.currentUser?.uid ?? 'anonymous';
                      await backupService.exportBackupZip(
                          widget.apiService, userId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  AppStrings.t(context, 'backup_success'))),
                        );
                      }
                    }),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: Text(widget.locale.languageCode == 'ar'
                ? 'رفع إلى Google Drive'
                : 'Upload to Google Drive'),
            trailing: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _busy
                ? null
                : () async {
                    final folderId = await _pickDriveFolder();
                    if (folderId == null) return;
                    _safeAction(() async {
                      final backupService = BackupService();
                      final userId =
                          widget.authService.currentUser?.uid ?? 'anonymous';
                      final fileId = await backupService.uploadToDrive(null,
                          apiService: widget.apiService,
                          userId: userId,
                          folderId: folderId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                            fileId != null
                                ? (widget.locale.languageCode == 'ar'
                                    ? 'تم الرفع إلى Google Drive بنجاح'
                                    : 'Uploaded to Google Drive successfully')
                                : (widget.locale.languageCode == 'ar'
                                    ? 'فشل الرفع. تأكد من تسجيل الدخول بحساب Google'
                                    : 'Upload failed. Make sure you\'re signed in with Google'),
                          )),
                        );
                      }
                    });
                  },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: Text(AppStrings.t(context, 'import_backup')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy
                ? null
                : () async {
                    if (kIsWeb) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text(AppStrings.t(context, 'backup_web_hint'))),
                      );
                      return;
                    }
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(AppStrings.t(context, 'import_backup')),
                        content: Text(AppStrings.t(context, 'restore_confirm')),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(AppStrings.t(context, 'cancel'))),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child:
                                  Text(AppStrings.t(context, 'import_backup'))),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    final pick =
                        await FilePicker.platform.pickFiles(withData: true);
                    if (pick == null ||
                        pick.files.isEmpty ||
                        pick.files.first.bytes == null) return;
                    _safeAction(() async {
                      final backupService = BackupService();
                      final userId =
                          widget.authService.currentUser?.uid ?? 'anonymous';
                      await backupService.restoreFromPickedBytes(
                          pick.files.first.bytes!, userId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text(AppStrings.t(context, 'restore_success')),
                        ));
                        // Reload settings from restored DB and push to app
                        try {
                          final restoredSettings =
                              await widget.apiService.getSettings();
                          if (restoredSettings != null && mounted) {
                            final theme = restoredSettings['theme']?.toString();
                            final locale =
                                restoredSettings['locale']?.toString();
                            if (theme != null) {
                              widget.onThemeChanged(theme == 'dark');
                            }
                            if (locale != null) {
                              widget.onLocaleChanged(Locale(locale));
                            }
                          }
                        } catch (_) {}
                        await _load();
                      }
                    });
                  },
          ),
        ],
      ),
    );
  }

  void _onTabChanged(int index) {
    setState(() => _selectedTab = index);
    if (index == 0) {
      _safeAction(_load);
    }
  }

  void _showMemberMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                      child: Text(AppStrings.t(context, 'members'),
                          style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _memberDialog();
                    },
                    icon: const Icon(Icons.person_add),
                    tooltip: AppStrings.t(context, 'add_member'),
                  ),
                ],
              ),
            ),
            const Divider(height: 0),
            if (_members.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(AppStrings.t(context, 'no_data')),
              )
            else
              ..._members.map((member) {
                final m = member as Map<String, dynamic>;
                final memberId = m['id'] as int;
                final isSelected = memberId == _selectedMemberId;
                final isDefault = memberId == _defaultMemberId;
                return ListTile(
                  leading: Icon(
                    isDefault ? Icons.star : Icons.person,
                    color: isDefault
                        ? Colors.amber
                        : isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                  ),
                  title: Text(m['name']?.toString() ?? ''),
                  subtitle: Text(m['relation']?.toString() ?? ''),
                  selected: isSelected,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isDefault ? Icons.star : Icons.star_border,
                          size: 20,
                          color: isDefault ? Colors.amber : null,
                        ),
                        tooltip: AppStrings.t(context, 'set_default'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _safeAction(() async {
                            final newDefault = isDefault ? null : memberId;
                            await widget.apiService
                                .setDefaultMemberId(newDefault);
                            _defaultMemberId = newDefault;
                            setState(() {});
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _memberDialog(existing: m);
                        },
                      ),
                      if (isSelected) const Icon(Icons.check, size: 20),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _safeAction(() async {
                      _selectedMemberId = memberId;
                      await _load();
                    });
                  },
                );
              }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String get _currentMemberName {
    if (_selectedMemberId == null || _members.isEmpty) return '';
    final m = _members
        .cast<Map<String, dynamic>>()
        .where((m) => m['id'] == _selectedMemberId)
        .firstOrNull;
    return m?['name']?.toString() ?? '';
  }

  Widget _buildLoadingSkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerBase =
        isDark ? const Color(0xFF2A2520) : const Color(0xFFEDE5D3);
    final shimmerHighlight =
        isDark ? const Color(0xFF1E1B16) : const Color(0xFFF7F2E8);

    Widget shimmerBox(
        {double? width, required double height, double radius = 20}) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.3, end: 1.0),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Color.lerp(shimmerBase, shimmerHighlight, value),
              borderRadius: BorderRadius.circular(radius),
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              shimmerBox(width: 40, height: 40, radius: 12),
              const SizedBox(width: 12),
              shimmerBox(width: 120, height: 22),
              const Spacer(),
              shimmerBox(width: 70, height: 28, radius: 8),
            ],
          ),
          const SizedBox(height: 20),
          shimmerBox(height: 150, radius: 20),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: shimmerBox(height: 120, radius: 20)),
              const SizedBox(width: 12),
              Expanded(child: shimmerBox(height: 120, radius: 20)),
            ],
          ),
          const SizedBox(height: 14),
          shimmerBox(height: 120, radius: 20),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: shimmerBox(height: 120, radius: 20)),
              const SizedBox(width: 12),
              Expanded(child: shimmerBox(height: 120, radius: 20)),
            ],
          ),
          const SizedBox(height: 20),
          shimmerBox(height: 76, radius: 20),
          const SizedBox(height: 16),
          shimmerBox(height: 160, radius: 22),
        ],
      ),
    );
  }

  Widget _emptyStateWidget({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: isDark ? 0.35 : 0.25,
              child: const IgLogo(size: 56),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                    fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              _goldGradientButton(
                onPressed: onAction,
                label: actionLabel,
                icon: Icons.add,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _goldGradientButton({
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8CD5A), Color(0xFFD4AF37), Color(0xFFC9A227)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: kGoldPrimary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: kDarkBase),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kDarkBase,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = isDark ? kGoldPrimary : kGoldMuted;

    return PremiumBackground(
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              SelectionContainer.disabled(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _onTabChanged(0),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IgLogo(size: 66),
                        InstaGoldWordmark(fontSize: 24),
                      ],
                    ),
                  ),
                ),
              ),
              if (_currentMemberName.isNotEmpty) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _showMemberMenu,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: isDark ? 0.12 : 0.35),
                          borderRadius: BorderRadius.circular(8),
                          border: isDark
                              ? Border.all(
                                  color: gold.withValues(alpha: 0.15),
                                  width: 0.5)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person, size: 14, color: gold),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 116),
                              child: Text(
                                _currentMemberName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: gold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (_members.isEmpty)
              IconButton(
                onPressed: _busy ? null : () => _memberDialog(),
                icon: const Icon(Icons.person_add_outlined),
                tooltip: AppStrings.t(context, 'add_member'),
              ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PriceAlertsScreen(
                    apiService: widget.apiService,
                    locale: widget.locale,
                  ),
                ),
              ),
              icon: const Icon(Icons.notifications_outlined, size: 22),
              tooltip: widget.locale.languageCode == 'ar'
                  ? 'تنبيهات الأسعار'
                  : 'Price Alerts',
            ),
            IconButton(
              onPressed: () {
                widget.authService.logout();
                widget.onLogout?.call();
              },
              icon: const Icon(Icons.logout, size: 20),
              tooltip: AppStrings.t(context, 'logout'),
            ),
          ],
            ),
          ),
        ),
        body: _loading
            ? _buildLoadingSkeleton()
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                child: IndexedStack(
                  index: _selectedTab,
                  children: [
                    _overviewTab(),
                    _assetsTab(),
                    _savingsGoalsTab(),
                    _companiesSettingsTab(),
                  ],
                ),
              ),
        extendBody: true,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb) const InstaGoldAdBanner(),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                gradient: isDark
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF1A1816).withValues(alpha: 0.92),
                          const Color(0xFF141210).withValues(alpha: 0.95),
                        ],
                      )
                    : null,
                color: isDark ? null : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(22),
                border: isDark
                    ? Border.all(
                        color: gold.withValues(alpha: 0.06), width: 0.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? gold.withValues(alpha: 0.06)
                        : gold.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 2),
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: NavigationBar(
                    selectedIndex: _selectedTab,
                    onDestinationSelected: _onTabChanged,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    destinations: [
                      NavigationDestination(
                          icon: const Icon(Icons.home_outlined),
                          selectedIcon: const Icon(Icons.home),
                          label: AppStrings.t(context, 'home')),
                      NavigationDestination(
                          icon: const Icon(Icons.workspace_premium_outlined),
                          selectedIcon: const Icon(Icons.workspace_premium),
                          label: AppStrings.t(context, 'my_gold')),
                      NavigationDestination(
                          icon: const Icon(Icons.account_balance_wallet_outlined),
                          selectedIcon: const Icon(Icons.account_balance_wallet),
                          label: AppStrings.t(context, 'savings_goals')),
                      NavigationDestination(
                          icon: const Icon(Icons.settings_outlined),
                          selectedIcon: const Icon(Icons.settings),
                          label: AppStrings.t(context, 'settings')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    List<Widget> actions = const [],
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? kGoldPrimary : kGoldMuted;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1C1916),
                  Color(0xFF1A1816),
                  Color(0xFF181614)
                ],
              )
            : null,
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? kGoldPrimary.withValues(alpha: 0.10)
              : accentColor.withValues(alpha: 0.08),
          width: 0.5,
        ),
        boxShadow: [
          if (isDark) ...[
            BoxShadow(
              color: kGoldPrimary.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ] else
            BoxShadow(
              color: accentColor.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  margin: const EdgeInsetsDirectional.only(end: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accentColor, accentColor.withValues(alpha: 0.4)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                  ),
                ),
                ...actions,
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 14),
              child: Divider(
                height: 0.5,
                thickness: 0.5,
                color: accentColor.withValues(alpha: 0.1),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Settings row with the user-facing "Price summaries" toggle. Wired through
/// [PushNotificationsService] so flipping it both persists locally and syncs
/// `summaries_enabled` to the backend (best-effort).
class _PushSummariesRow extends StatefulWidget {
  const _PushSummariesRow({
    required this.pushService,
    required this.apiService,
    required this.buildSettingsRow,
  });

  final PushNotificationsService pushService;
  final ApiService apiService;
  final Widget Function({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) buildSettingsRow;

  @override
  State<_PushSummariesRow> createState() => _PushSummariesRowState();
}

class _PushSummariesRowState extends State<_PushSummariesRow> {
  bool _enabled = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    PushNotificationsService.readSummariesEnabled().then((value) {
      if (mounted) setState(() => _enabled = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.buildSettingsRow(
      icon: Icons.notifications_active_outlined,
      title: AppStrings.t(context, 'price_summaries'),
      trailing: Switch.adaptive(
        value: _enabled,
        onChanged: _busy
            ? null
            : (next) async {
                setState(() {
                  _enabled = next;
                  _busy = true;
                });
                await widget.pushService
                    .setSummariesEnabled(widget.apiService, next);
                if (mounted) setState(() => _busy = false);
              },
      ),
    );
  }
}

