import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notifications_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.authService,
    required this.apiService,
    required this.notificationsService,
    required this.locale,
    required this.themeMode,
    required this.onLocaleChanged,
    required this.onThemeChanged,
  });

  final AuthService authService;
  final ApiService apiService;
  final NotificationsService notificationsService;
  final Locale locale;
  final ThemeMode themeMode;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _members = [];
  List<dynamic> _assets = [];
  List<dynamic> _goals = [];
  List<dynamic> _companies = [];
  List<dynamic> _savingEntries = [];
  double _totalSaved = 0;
  Map<String, dynamic>? _prices;
  int? _selectedMemberId;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _zakat;
  int _notificationInterval = 1;
  int _selectedTab = 0;
  bool _busy = false;
  bool _loading = true;
  final NumberFormat _currency = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _load();
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
      } catch (_) { /* session is optional */ }

      Map<String, dynamic>? prices;
      try {
        prices = await widget.apiService.getCurrentPrices();
      } catch (e) {
        errors.add('Prices: ${_cleanErrorMessage(e)}');
      }

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
          SnackBar(content: Text(errors.join(' | ')), duration: const Duration(seconds: 5)),
        );
      }
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
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final relation = TextEditingController(text: existing?['relation']?.toString() ?? '');
    final isEdit = existing != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Member' : AppStrings.t(context, 'add_member')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: InputDecoration(labelText: AppStrings.t(context, 'name'))),
            TextField(
              controller: relation,
              decoration: InputDecoration(labelText: AppStrings.t(context, 'relation')),
            ),
          ],
        ),
        actions: [
          if (isEdit)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Member?'),
                    content: Text('This will also delete all assets, savings and goals for "${existing['name']}".'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  Navigator.pop(context, false);
                  await _safeAction(() async {
                    await widget.apiService.deleteMember(existing['id'] as int);
                    _selectedMemberId = null;
                    await _load();
                  });
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.t(context, 'save'))),
        ],
      ),
    );
    if (saved == true && name.text.trim().isNotEmpty) {
      await _safeAction(() async {
        if (isEdit) {
          await widget.apiService.updateMember(existing['id'] as int, name.text.trim(), relation.text.trim());
        } else {
          await widget.apiService.addMember(name.text.trim(), relation.text.trim());
        }
        await _load();
      });
    }
  }

  static const _mainAssetTypes = ['jewellery', 'coins', 'ingot'];
  static const _jewellerySubTypes = ['ring', 'necklace', 'bracelet'];
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
    String selectedSubType = _jewellerySubTypes.contains(rawType) ? rawType : 'ring';
    String selectedCoinSize = 'pound';
    String selectedIngotSize = '10g';
    String selectedKarat = existing?['karat']?.toString() ?? '21k';
    final weight = TextEditingController(text: existing?['weight_g']?.toString() ?? '');
    final purchasePrice = TextEditingController(text: existing?['purchase_price']?.toString() ?? '');
    final purchaseDate = TextEditingController(
      text: existing?['purchase_date']?.toString() ?? DateTime.now().toIso8601String().split('T').first,
    );
    int? companyId = existing?['company_id'] as int?;
    bool weightLocked = false;

    String effectiveType() => selectedMainType == 'jewellery' ? selectedSubType : selectedMainType;

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
            title: Text(existing == null ? 'Add Asset' : 'Edit Asset'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedMainType,
                    decoration: const InputDecoration(labelText: 'Asset type'),
                    items: _mainAssetTypes.map((t) {
                      final label = t == 'jewellery' ? 'Jewellery' : t == 'coins' ? 'Coins' : 'Ingot';
                      return DropdownMenuItem(value: t, child: Text(label));
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
                      decoration: const InputDecoration(labelText: 'Jewellery type'),
                      items: _jewellerySubTypes.map((t) {
                        return DropdownMenuItem(value: t, child: Text(_assetTypeLabel(t)));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => selectedSubType = value);
                      },
                    ),
                  ],
                  if (selectedMainType == 'coins') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('coin_size'),
                      value: selectedCoinSize,
                      decoration: const InputDecoration(labelText: 'Coin size'),
                      items: _coinSizes.entries.map((e) {
                        final g = (e.value['grams']! as num);
                        final suffix = g > 0 ? ' (${g}g)' : '';
                        return DropdownMenuItem(value: e.key, child: Text('${e.value['label']}$suffix'));
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
                      decoration: const InputDecoration(labelText: 'Ingot size'),
                      items: _ingotSizes.entries.map((e) {
                        return DropdownMenuItem(value: e.key, child: Text('${e.value['label']}'));
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
                          ? 'Karat (default ${_defaultKarats[selectedMainType]} for $selectedMainType)'
                          : 'Karat',
                    ),
                    items: _karatOptions
                        .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selectedKarat = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: weight,
                    keyboardType: TextInputType.number,
                    readOnly: weightLocked,
                    decoration: InputDecoration(
                      labelText: 'Weight (g)',
                      suffixIcon: weightLocked
                          ? const Icon(Icons.lock_outline, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: purchasePrice,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Purchase price (EGP)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: purchaseDate,
                    decoration: const InputDecoration(labelText: 'Purchase date (YYYY-MM-DD)'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: companyId,
                    decoration: const InputDecoration(labelText: 'Company (optional)'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('None')),
                      ..._companies.map((company) {
                        return DropdownMenuItem<int?>(
                          value: company['id'] as int,
                          child: Text(company['name'].toString()),
                        );
                      }),
                    ],
                    onChanged: (value) => companyId = value,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.t(context, 'save'))),
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
          purchaseDate: purchaseDate.text.trim(),
          companyId: companyId,
        );
      } else {
        await widget.apiService.updateAsset(
          assetId: existing['id'] as int,
          assetType: finalType,
          karat: selectedKarat,
          weightG: weightValue,
          purchasePrice: purchaseValue,
          purchaseDate: purchaseDate.text.trim(),
          companyId: companyId,
        );
      }
      await _load();
    });
  }

  Future<void> _addSavingDialog() async {
    if (_selectedMemberId == null) return;
    final amount = TextEditingController();
    String? savingTargetType;
    String savingTargetKarat = '21k';
    String savingSubType = 'ring';
    String savingCoinSize = 'pound';
    String savingIngotSize = '10g';

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(AppStrings.t(context, 'add_saving')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: AppStrings.t(context, 'amount')),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: savingTargetType,
                    decoration: const InputDecoration(labelText: 'Saving target (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No target')),
                      ..._mainAssetTypes.map((t) {
                        final label = t == 'jewellery' ? 'Jewellery' : t == 'coins' ? 'Coins' : 'Ingot';
                        return DropdownMenuItem<String?>(value: t, child: Text(label));
                      }),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        savingTargetType = value;
                        if (value != null && _defaultKarats.containsKey(value)) {
                          savingTargetKarat = _defaultKarats[value]!;
                        }
                      });
                    },
                  ),
                  if (savingTargetType == 'jewellery') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('saving_jewellery_sub'),
                      value: savingSubType,
                      decoration: const InputDecoration(labelText: 'Jewellery type'),
                      items: _jewellerySubTypes.map((t) {
                        return DropdownMenuItem(value: t, child: Text(_assetTypeLabel(t)));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => savingSubType = value);
                      },
                    ),
                  ],
                  if (savingTargetType == 'coins') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('saving_coin_size'),
                      value: savingCoinSize,
                      decoration: const InputDecoration(labelText: 'Coin size'),
                      items: _coinSizes.entries.where((e) => e.key != 'manual').map((e) {
                        final g = (e.value['grams']! as num);
                        return DropdownMenuItem(value: e.key, child: Text('${e.value['label']} (${g}g)'));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => savingCoinSize = value);
                      },
                    ),
                  ],
                  if (savingTargetType == 'ingot') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('saving_ingot_size'),
                      value: savingIngotSize,
                      decoration: const InputDecoration(labelText: 'Ingot size'),
                      items: _ingotSizes.entries.where((e) => e.key != 'manual').map((e) {
                        return DropdownMenuItem(value: e.key, child: Text('${e.value['label']}'));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => savingIngotSize = value);
                      },
                    ),
                  ],
                  if (savingTargetType != null) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('saving_karat_$savingTargetType'),
                      value: savingTargetKarat,
                      decoration: const InputDecoration(labelText: 'Target karat'),
                      items: _karatOptions.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => savingTargetKarat = value);
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.t(context, 'save'))),
            ],
          );
        },
      ),
    );
    if (saved != true) return;
    final value = double.tryParse(amount.text) ?? 0;
    if (value <= 0) return;

    final effectiveTarget = savingTargetType == 'jewellery' ? savingSubType : savingTargetType;
    await _safeAction(() async {
      await widget.apiService.addSaving(
        _selectedMemberId!,
        value,
        targetType: effectiveTarget,
        targetKarat: savingTargetType != null ? savingTargetKarat : null,
      );
      await _load();
    });
  }

  Future<void> _addGoalDialog() async {
    if (_selectedMemberId == null) return;
    String goalMainType = 'jewellery';
    String goalSubType = 'ring';
    String goalCoinSize = 'pound';
    String goalIngotSize = '10g';
    String goalKarat = '21k';
    final targetWeight = TextEditingController();
    final savedAmount = TextEditingController(text: _totalSaved.toStringAsFixed(2));
    int? companyId;
    bool goalWeightLocked = false;

    void applyGoalWeight(StateSetter setDialogState) {
      if (goalMainType == 'coins' && goalCoinSize != 'manual') {
        targetWeight.text = (_coinSizes[goalCoinSize]!['grams']! as num).toString();
        goalWeightLocked = true;
      } else if (goalMainType == 'ingot' && goalIngotSize != 'manual') {
        targetWeight.text = (_ingotSizes[goalIngotSize]!['grams']! as num).toString();
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
            title: const Text('Add Goal'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: goalMainType,
                    decoration: const InputDecoration(labelText: 'Goal type'),
                    items: _mainAssetTypes.map((t) {
                      final label = t == 'jewellery' ? 'Jewellery' : t == 'coins' ? 'Coins' : 'Ingot';
                      return DropdownMenuItem(value: t, child: Text(label));
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
                      decoration: const InputDecoration(labelText: 'Jewellery type'),
                      items: _jewellerySubTypes.map((t) {
                        return DropdownMenuItem(value: t, child: Text(_assetTypeLabel(t)));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => goalSubType = value);
                      },
                    ),
                  ],
                  if (goalMainType == 'coins') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('goal_coin_size'),
                      value: goalCoinSize,
                      decoration: const InputDecoration(labelText: 'Coin size'),
                      items: _coinSizes.entries.map((e) {
                        final g = (e.value['grams']! as num);
                        final suffix = g > 0 ? ' (${g}g)' : '';
                        return DropdownMenuItem(value: e.key, child: Text('${e.value['label']}$suffix'));
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
                      decoration: const InputDecoration(labelText: 'Ingot size'),
                      items: _ingotSizes.entries.map((e) {
                        return DropdownMenuItem(value: e.key, child: Text('${e.value['label']}'));
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
                          ? 'Karat (default ${_defaultKarats[goalMainType]})'
                          : 'Karat',
                    ),
                    items: _karatOptions.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => goalKarat = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: targetWeight,
                    keyboardType: TextInputType.number,
                    readOnly: goalWeightLocked,
                    decoration: InputDecoration(
                      labelText: 'Target weight (g)',
                      suffixIcon: goalWeightLocked
                          ? const Icon(Icons.lock_outline, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: savedAmount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Saved amount (EGP)'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: companyId,
                    decoration: const InputDecoration(labelText: 'Company (optional)'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('None')),
                      ..._companies.map((company) => DropdownMenuItem<int?>(
                            value: company['id'] as int,
                            child: Text(company['name'].toString()),
                          )),
                    ],
                    onChanged: (value) => companyId = value,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.t(context, 'save'))),
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
        savedAmount: double.tryParse(savedAmount.text) ?? 0,
        companyId: companyId,
      );
      await _load();
    });
  }

  Future<void> _updateGoalSavedDialog(Map<String, dynamic> goal) async {
    final savedAmount = TextEditingController(text: goal['saved_amount'].toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Goal Saving'),
        content: TextField(
          controller: savedAmount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Saved amount (EGP)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.t(context, 'save'))),
        ],
      ),
    );
    if (saved != true) return;
    await _safeAction(() async {
      await widget.apiService.updateGoalSaved(
        goalId: goal['id'] as int,
        savedAmount: double.tryParse(savedAmount.text) ?? 0,
      );
      await _load();
    });
  }

  Future<void> _addCompanyDialog() async {
    final name = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Company'),
        content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Company name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.t(context, 'save'))),
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

  Widget _ingotCard({
    required String label,
    required String karat,
    bool isHero = false,
    double? width,
  }) {
    final data = _priceFor(karat);
    final buy = data != null ? _currency.format(data['buy_price']) : '—';
    final sell = data != null ? _currency.format(data['sell_price']) : '—';
    final currency = data?['currency']?.toString() ?? 'EGP';

    final height = isHero ? 170.0 : 130.0;
    final labelSize = isHero ? 28.0 : 18.0;
    final priceSize = isHero ? 32.0 : 20.0;
    final subSize = isHero ? 14.0 : 12.0;

    final goldGradient = isHero
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD4A844), Color(0xFFB8860B), Color(0xFF8B6914)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFC9983A), Color(0xFFA67C2E), Color(0xFF7A5B1E)],
          );

    return SizedBox(
      width: width,
      height: height,
      child: ClipPath(
        clipper: _IngotClipper(),
        child: Container(
          decoration: BoxDecoration(gradient: goldGradient),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: labelSize,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black38)],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$sell $currency',
                style: TextStyle(
                  fontSize: priceSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 3, color: Colors.black26)],
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Buy: $buy', style: TextStyle(fontSize: subSize, color: Colors.white70)),
                  Text('  |  ', style: TextStyle(fontSize: subSize, color: Colors.white38)),
                  Text('Sell: $sell', style: TextStyle(fontSize: subSize, color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _poundCard() {
    final data = _priceFor('gold_pound_8g');
    final price = data != null ? _currency.format(data['sell_price']) : '—';
    return SizedBox(
      height: 130,
      child: ClipPath(
        clipper: _CoinClipper(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD4A844), Color(0xFFB8860B), Color(0xFF8B6914)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Gold\nPound', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black38)])),
                const SizedBox(height: 4),
                Text('$price EGP', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
                    shadows: [Shadow(blurRadius: 3, color: Colors.black26)])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ounceCard() {
    final data = _priceFor('ounce');
    final price = data != null ? _currency.format(data['sell_price']) : '—';
    return SizedBox(
      height: 130,
      child: ClipPath(
        clipper: _CoinClipper(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE8C4B8), Color(0xFFBF8070), Color(0xFF9B6155)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Global\nOunce', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black38)])),
                const SizedBox(height: 4),
                Text('$price USD', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
                    shadows: [Shadow(blurRadius: 3, color: Colors.black26)])),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _overviewTab() {
    final updatedAt = _prices?['updated_at']?.toString() ?? '';
    final timeLabel = updatedAt.isNotEmpty
        ? updatedAt.split('T').last.split('.').first.substring(0, 5)
        : '—';

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${AppStrings.t(context, 'live_prices')}  ($timeLabel)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => _safeAction(() async {
                        await widget.apiService.syncPrices();
                        await _load();
                      }),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(AppStrings.t(context, 'sync_prices')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ingotCard(label: '21 Karat', karat: '21k', isHero: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ingotCard(label: '24K', karat: '24k')),
            const SizedBox(width: 10),
            Expanded(child: _ingotCard(label: '18K', karat: '18k')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _ingotCard(label: '14K', karat: '14k')),
            const SizedBox(width: 10),
            Expanded(child: _poundCard()),
          ],
        ),
        const SizedBox(height: 10),
        Center(child: SizedBox(width: 180, child: _ounceCard())),
        const SizedBox(height: 16),
        if (_summary != null) ...[
          _sectionCard(
            title: 'Asset Summary',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _totalRow('Current value', '${_currency.format(_summary!['summary']['current_value'])} EGP'),
                _totalRow('Purchase cost', '${_currency.format(_summary!['summary']['purchase_cost'])} EGP'),
                _totalRow(
                  'Profit/Loss',
                  '${_currency.format(_summary!['summary']['profit_loss'])} EGP',
                  valueColor: (_summary!['summary']['profit_loss'] as num) >= 0 ? Colors.green : Colors.red,
                ),
                _totalRow('24k equivalent', '${_currency.format(_summary!['summary']['total_weight_24k_equivalent'])} g'),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_zakat != null)
          _sectionCard(
            title: AppStrings.t(context, 'zakat'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _totalRow('Eligible', '${_zakat!['zakat']['eligible']}'),
                _totalRow('Zakat due', '${_currency.format(_zakat!['zakat']['zakat_due'])} EGP'),
                _totalRow(
                  'Threshold / Current',
                  '${_zakat!['zakat']['threshold_weight_24k']}g / '
                  '${_currency.format(_zakat!['total_weight_24k_equivalent'])}g',
                ),
              ],
            ),
          ),
      ],
    );
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
      title: 'Portfolio Totals',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPricesAvailable) ...[
            _totalRow('Current Value', '${_currency.format(totalCurrentValue)} EGP'),
            _totalRow('Purchase Cost', '${_currency.format(totalPurchaseCost)} EGP'),
            _totalRow(
              'Profit / Loss',
              '${profitLoss >= 0 ? '+' : ''}${_currency.format(profitLoss)} EGP',
              valueColor: profitLoss >= 0 ? Colors.green : Colors.red,
            ),
            if (totalPurchaseCost > 0)
              _totalRow(
                'Return',
                '${(profitLoss / totalPurchaseCost * 100).toStringAsFixed(1)}%',
                valueColor: profitLoss >= 0 ? Colors.green : Colors.red,
              ),
          ] else
            const Text('Prices unavailable - values approximate'),
          const Divider(),
          Text('Weight by Karat', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          ...gramsByKarat.entries.map(
            (e) => _totalRow(e.key, '${_currency.format(e.value)} g'),
          ),
          _totalRow(
            'Total',
            '${_currency.format(gramsByKarat.values.fold(0.0, (a, b) => a + b))} g',
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  String _assetTypeLabel(String type) {
    switch (type) {
      case 'ring': return 'Ring';
      case 'necklace': return 'Necklace';
      case 'bracelet': return 'Bracelet';
      case 'coins': return 'Coins';
      case 'ingot': return 'Ingot';
      case 'jewellery': return 'Jewellery';
      default: return type;
    }
  }

  CustomClipper<Path> _clipperForType(String type) {
    switch (type) {
      case 'coins': return _CoinClipper();
      case 'ingot': return _IngotClipper();
      case 'ring': return _RingClipper();
      case 'necklace': return _NecklaceClipper();
      case 'bracelet': return _BraceletClipper();
      default: return _IngotClipper();
    }
  }

  List<Color> _gradientForType(String type) {
    switch (type) {
      case 'coins':
        return const [Color(0xFFD4A844), Color(0xFFBFA23A), Color(0xFF8B6914)];
      case 'ingot':
        return const [Color(0xFFC9983A), Color(0xFFA67C2E), Color(0xFF7A5B1E)];
      case 'ring':
        return const [Color(0xFFE8D5A3), Color(0xFFD4A844), Color(0xFFA67C2E)];
      case 'necklace':
        return const [Color(0xFFF0E0B0), Color(0xFFD4A844), Color(0xFF9B7A2F)];
      case 'bracelet':
        return const [Color(0xFFE8C880), Color(0xFFCCA840), Color(0xFF8B6914)];
      default:
        return const [Color(0xFFC9983A), Color(0xFFA67C2E), Color(0xFF7A5B1E)];
    }
  }

  Widget _assetShapeIcon(String type, {double size = 36}) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipPath(
        clipper: _clipperForType(type),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _gradientForType(type),
            ),
          ),
        ),
      ),
    );
  }

  Widget _assetsTab() {
    return ListView(
      children: [
        _assetsTotalsCard(),
        if (_assets.isNotEmpty) const SizedBox(height: 12),
        _sectionCard(
          title: 'Assets (${_assets.length})',
          actions: [
            IconButton(
              onPressed: _selectedMemberId == null || _busy ? null : () => _addAssetDialog(),
              icon: const Icon(Icons.add),
            ),
          ],
          child: _assets.isEmpty
              ? Text(AppStrings.t(context, 'no_data'))
              : Column(
                  children: _assets.map((asset) {
                    final type = asset['asset_type']?.toString() ?? 'jewellery';
                    final currentVal = _currentValueForAsset(asset as Map<String, dynamic>);
                    final purchaseVal = (asset['purchase_price'] as num?)?.toDouble() ?? 0;
                    final assetPL = currentVal - purchaseVal;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _assetShapeIcon(type),
                      title: Text(
                        '${_assetTypeLabel(type)} - ${asset['karat']} - ${asset['weight_g']}g',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchased: ${_currency.format(purchaseVal)} EGP (${asset['purchase_date']})',
                          ),
                          if (_prices != null)
                            Text(
                              'Now: ${_currency.format(currentVal)} EGP  '
                              '(${assetPL >= 0 ? '+' : ''}${_currency.format(assetPL)})',
                              style: TextStyle(
                                color: assetPL >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            onPressed: () => _addAssetDialog(existing: asset),
                            icon: const Icon(Icons.edit, size: 20),
                          ),
                          IconButton(
                            onPressed: _busy
                                ? null
                                : () => _safeAction(() async {
                                      await widget.apiService.deleteAsset(asset['id'] as int);
                                      await _load();
                                    }),
                            icon: const Icon(Icons.delete, size: 20),
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

  Widget _savingsGoalsTab() {
    return ListView(
      children: [
        _sectionCard(
          title: 'Savings',
          actions: [
            IconButton(
              onPressed: _selectedMemberId == null || _busy ? null : _addSavingDialog,
              icon: const Icon(Icons.add),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total saved: ${_currency.format(_totalSaved)} EGP'),
              const SizedBox(height: 8),
              if (_savingEntries.isEmpty) Text(AppStrings.t(context, 'no_data')),
              ..._savingEntries.take(7).map((entry) {
                final targetType = entry['target_type']?.toString();
                final targetKarat = entry['target_karat']?.toString();
                final targetLabel = targetType != null
                    ? '${_assetTypeLabel(targetType)} ${targetKarat ?? ''}'.trim()
                    : '';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: targetType != null ? _assetShapeIcon(targetType, size: 28) : null,
                  title: Text('${_currency.format(entry['amount'])} ${entry['currency']}'),
                  subtitle: Text(
                    '${entry['created_at']}${targetLabel.isNotEmpty ? '  •  Target: $targetLabel' : ''}',
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Goals',
          actions: [
            IconButton(
              onPressed: _selectedMemberId == null || _busy ? null : _addGoalDialog,
              icon: const Icon(Icons.add),
            ),
          ],
          child: _goals.isEmpty
              ? Text(AppStrings.t(context, 'no_data'))
              : Column(
                  children: _goals.map((goal) {
                    final target = (goal['target_price'] as num?)?.toDouble() ?? 0;
                    final saved = (goal['saved_amount'] as num?)?.toDouble() ?? 0;
                    final progress = target > 0 ? (saved / target).clamp(0, 1) : 0.0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${goal['karat']} - ${goal['target_weight_g']}g'),
                          subtitle: Text(
                            'Target: ${_currency.format(goal['target_price'])} | '
                            'Remaining: ${_currency.format(goal['remaining_amount'])} EGP',
                          ),
                          trailing: IconButton(
                            onPressed: () => _updateGoalSavedDialog(goal as Map<String, dynamic>),
                            icon: const Icon(Icons.savings),
                          ),
                        ),
                        LinearProgressIndicator(value: progress.toDouble()),
                        const SizedBox(height: 10),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _companiesSettingsTab() {
    return ListView(
      children: [
        _sectionCard(
          title: 'Companies',
          actions: [
            IconButton(onPressed: _busy ? null : _addCompanyDialog, icon: const Icon(Icons.add_business)),
          ],
          child: _companies.isEmpty
              ? Text(AppStrings.t(context, 'no_data'))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _companies
                      .map((company) => Chip(label: Text(company['name'].toString())))
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: AppStrings.t(context, 'settings'),
          child: Column(
            children: [
              SwitchListTile(
                value: widget.themeMode == ThemeMode.dark,
                onChanged: widget.onThemeChanged,
                title: Text(AppStrings.t(context, 'dark_mode')),
              ),
              ListTile(
                title: Text(AppStrings.t(context, 'language')),
                subtitle: Text(widget.locale.languageCode == 'en' ? 'English' : 'العربية'),
                trailing: IconButton(
                  icon: const Icon(Icons.language),
                  onPressed: () {
                    widget.onLocaleChanged(
                      widget.locale.languageCode == 'en' ? const Locale('ar') : const Locale('en'),
                    );
                  },
                ),
              ),
              DropdownButtonFormField<int>(
                initialValue: _notificationInterval,
                decoration: InputDecoration(labelText: AppStrings.t(context, 'notification_interval')),
                items: [
                  DropdownMenuItem(value: 1, child: Text(AppStrings.t(context, 'hourly'))),
                  DropdownMenuItem(value: 6, child: Text(AppStrings.t(context, 'six_hours'))),
                ],
                onChanged: (value) => setState(() => _notificationInterval = value ?? 1),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _busy
                    ? null
                    : () => _safeAction(() async {
                          await widget.apiService.updateSettings(
                            locale: widget.locale.languageCode,
                            theme: widget.themeMode == ThemeMode.dark ? 'dark' : 'light',
                            notificationIntervalHours: _notificationInterval,
                          );
                          await widget.notificationsService.showSettingsSavedNotification();
                        }),
                child: Text(AppStrings.t(context, 'save')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onTabChanged(int index) {
    setState(() => _selectedTab = index);
    if (index == 0) {
      _safeAction(() async {
        await widget.apiService.syncPrices();
        await _load();
      });
    }
  }

  void _showMemberMenu() {
    final selectedMember = _selectedMemberId != null
        ? _members.cast<Map<String, dynamic>>().where((m) => m['id'] == _selectedMemberId).firstOrNull
        : null;

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
                  Expanded(child: Text(AppStrings.t(context, 'members'),
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
                final isSelected = m['id'] == _selectedMemberId;
                return ListTile(
                  leading: Icon(Icons.person, color: isSelected ? Theme.of(context).colorScheme.primary : null),
                  title: Text(m['name']?.toString() ?? ''),
                  subtitle: Text(m['relation']?.toString() ?? ''),
                  selected: isSelected,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      _selectedMemberId = m['id'] as int;
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
    final m = _members.cast<Map<String, dynamic>>().where((m) => m['id'] == _selectedMemberId).firstOrNull;
    return m?['name']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'app_title')),
        actions: [
          if (_members.isNotEmpty)
            TextButton.icon(
              onPressed: _showMemberMenu,
              icon: const Icon(Icons.people, size: 20),
              label: Text(_currentMemberName, overflow: TextOverflow.ellipsis),
            ),
          if (_members.isEmpty)
            IconButton(
              onPressed: _busy ? null : () => _memberDialog(),
              icon: const Icon(Icons.person_add),
              tooltip: AppStrings.t(context, 'add_member'),
            ),
          IconButton(
            onPressed: _busy ? null : () => _safeAction(_load),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: widget.authService.logout,
            icon: const Icon(Icons.logout),
            tooltip: AppStrings.t(context, 'logout'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: _onTabChanged,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.workspace_premium), label: 'My Gold'),
          NavigationDestination(icon: Icon(Icons.savings), label: 'Savings/Goals'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    List<Widget> actions = const [],
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                ...actions,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _IngotClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final inset = w * 0.06;
    final r = h * 0.12;
    return Path()
      ..moveTo(inset + r, 0)
      ..lineTo(w - inset - r, 0)
      ..quadraticBezierTo(w - inset, 0, w - inset, r)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(inset, r)
      ..quadraticBezierTo(inset, 0, inset + r, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CoinClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide / 2;
    return Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _RingClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final rx = w / 2;
    final ry = h * 0.42;
    return Path()..addOval(Rect.fromCenter(center: Offset(rx, h / 2), width: rx * 2, height: ry * 2));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _NecklaceClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = h * 0.15;
    return Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h * 0.5)
      ..quadraticBezierTo(w, h * 0.7, w * 0.75, h * 0.85)
      ..quadraticBezierTo(w * 0.5, h * 1.05, w * 0.25, h * 0.85)
      ..quadraticBezierTo(0, h * 0.7, 0, h * 0.5)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BraceletClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = h * 0.3;
    return Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
