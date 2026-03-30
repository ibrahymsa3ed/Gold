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
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await widget.apiService.createSession();
      final prices = await widget.apiService.getCurrentPrices();
      final members = await widget.apiService.getMembers();
      final companies = await widget.apiService.getCompanies();
      Map<String, dynamic>? summary;
      Map<String, dynamic>? zakat;
      List<dynamic> assets = [];
      List<dynamic> goals = [];
      List<dynamic> savingEntries = [];
      double totalSaved = 0;
      int? selectedId;
      if (members.isNotEmpty) {
        selectedId = _selectedMemberId ?? members.first['id'] as int;
        final summaryF = widget.apiService.getMemberSummary(selectedId);
        final zakatF = widget.apiService.getMemberZakat(selectedId);
        final assetsF = widget.apiService.getMemberAssets(selectedId);
        final goalsF = widget.apiService.getGoals(selectedId);
        final savingsF = widget.apiService.getSavings(selectedId);
        final results = await Future.wait([summaryF, zakatF, assetsF, goalsF, savingsF]);
        summary = results[0] as Map<String, dynamic>;
        zakat = results[1] as Map<String, dynamic>;
        assets = results[2] as List<dynamic>;
        goals = results[3] as List<dynamic>;
        final savingsData = results[4] as Map<String, dynamic>;
        savingEntries = (savingsData['entries'] as List<dynamic>? ?? []);
        totalSaved = (savingsData['total_saved'] as num?)?.toDouble() ?? 0;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMemberDialog() async {
    final name = TextEditingController();
    final relation = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.t(context, 'add_member')),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.t(context, 'save'))),
        ],
      ),
    );
    if (saved == true && name.text.trim().isNotEmpty) {
      await _safeAction(() async {
        await widget.apiService.addMember(name.text.trim(), relation.text.trim());
        await _load();
      });
    }
  }

  Future<void> _addAssetDialog({Map<String, dynamic>? existing}) async {
    if (_selectedMemberId == null) return;
    final assetType = TextEditingController(text: existing?['asset_type']?.toString() ?? 'jewellery');
    final karat = TextEditingController(text: existing?['karat']?.toString() ?? '21k');
    final weight = TextEditingController(text: existing?['weight_g']?.toString() ?? '');
    final purchasePrice = TextEditingController(text: existing?['purchase_price']?.toString() ?? '');
    final purchaseDate = TextEditingController(
      text: existing?['purchase_date']?.toString() ?? DateTime.now().toIso8601String().split('T').first,
    );
    int? companyId = existing?['company_id'] as int?;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add Asset' : 'Edit Asset'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: assetType, decoration: const InputDecoration(labelText: 'Type')),
              TextField(controller: karat, decoration: const InputDecoration(labelText: 'Karat (24k/21k/18k/14k)')),
              TextField(
                controller: weight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weight (g)'),
              ),
              TextField(
                controller: purchasePrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Purchase price (EGP)'),
              ),
              TextField(
                controller: purchaseDate,
                decoration: const InputDecoration(labelText: 'Purchase date (YYYY-MM-DD)'),
              ),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.t(context, 'save'))),
        ],
      ),
    );
    if (saved != true) return;

    final weightValue = double.tryParse(weight.text) ?? 0;
    final purchaseValue = double.tryParse(purchasePrice.text) ?? 0;
    if (weightValue <= 0 || purchaseValue <= 0) return;

    await _safeAction(() async {
      if (existing == null) {
        await widget.apiService.addAsset(
          memberId: _selectedMemberId!,
          assetType: assetType.text.trim(),
          karat: karat.text.trim(),
          weightG: weightValue,
          purchasePrice: purchaseValue,
          purchaseDate: purchaseDate.text.trim(),
          companyId: companyId,
        );
      } else {
        await widget.apiService.updateAsset(
          assetId: existing['id'] as int,
          assetType: assetType.text.trim(),
          karat: karat.text.trim(),
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.t(context, 'add_saving')),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: AppStrings.t(context, 'amount')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.t(context, 'save'))),
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

  Future<void> _addGoalDialog() async {
    if (_selectedMemberId == null) return;
    final karat = TextEditingController(text: '24k');
    final targetWeight = TextEditingController();
    final savedAmount = TextEditingController(text: _totalSaved.toStringAsFixed(2));
    int? companyId;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Goal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: karat, decoration: const InputDecoration(labelText: 'Karat')),
              TextField(
                controller: targetWeight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target weight (g)'),
              ),
              TextField(
                controller: savedAmount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Saved amount (EGP)'),
              ),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.t(context, 'save'))),
        ],
      ),
    );
    if (saved != true) return;
    await _safeAction(() async {
      await widget.apiService.createGoal(
        memberId: _selectedMemberId!,
        karat: karat.text.trim(),
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

  Widget _pricesView() {
    if (_prices == null) return Text(AppStrings.t(context, 'no_data'));
    final prices = (_prices!['prices'] as Map<String, dynamic>? ?? {});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Last update: ${_prices!['updated_at'] ?? '-'}'),
        const SizedBox(height: 8),
        ...prices.entries.map((entry) {
          final value = entry.value as Map<String, dynamic>;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(entry.key),
            subtitle: Text(
              'Buy: ${_currency.format(value['buy_price'])} | '
              'Sell: ${_currency.format(value['sell_price'])} ${value['currency']}',
            ),
          );
        }),
      ],
    );
  }

  Widget _memberSelector() {
    if (_members.isEmpty) return Text(AppStrings.t(context, 'no_data'));
    return Row(
      children: [
        const Icon(Icons.person),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedMemberId,
            decoration: const InputDecoration(
              labelText: 'Active member',
              border: OutlineInputBorder(),
            ),
            items: _members
                .map(
                  (member) => DropdownMenuItem<int>(
                    value: member['id'] as int,
                    child: Text('${member['name']} (${member['relation'] ?? '-'})'),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              await _safeAction(() async {
                _selectedMemberId = value;
                await _load();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _overviewTab() {
    return ListView(
      children: [
        _sectionCard(
          title: AppStrings.t(context, 'live_prices'),
          actions: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _safeAction(() async {
                        await widget.apiService.syncPrices();
                        await _load();
                      }),
              child: Text(AppStrings.t(context, 'sync_prices')),
            )
          ],
          child: _pricesView(),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Asset Summary',
          child: _summary == null
              ? Text(AppStrings.t(context, 'no_data'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current value: ${_currency.format(_summary!['summary']['current_value'])} EGP'),
                    Text('Purchase cost: ${_currency.format(_summary!['summary']['purchase_cost'])} EGP'),
                    Text('Profit/Loss: ${_currency.format(_summary!['summary']['profit_loss'])} EGP'),
                    Text('24k equivalent: ${_currency.format(_summary!['summary']['total_weight_24k_equivalent'])} g'),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: AppStrings.t(context, 'zakat'),
          child: _zakat == null
              ? Text(AppStrings.t(context, 'no_data'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Eligible: ${_zakat!['zakat']['eligible']}'),
                    Text('Zakat due: ${_currency.format(_zakat!['zakat']['zakat_due'])} EGP'),
                    Text(
                      'Threshold: ${_zakat!['zakat']['threshold_weight_24k']}g | '
                      'Current: ${_currency.format(_zakat!['total_weight_24k_equivalent'])}g',
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _assetsTab() {
    return ListView(
      children: [
        _sectionCard(
          title: 'Assets',
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
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${asset['asset_type']} - ${asset['karat']} - ${asset['weight_g']}g',
                      ),
                      subtitle: Text(
                        'Purchase: ${_currency.format(asset['purchase_price'])} EGP '
                        '(${asset['purchase_date']})',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            onPressed: () => _addAssetDialog(existing: asset as Map<String, dynamic>),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            onPressed: _busy
                                ? null
                                : () => _safeAction(() async {
                                      await widget.apiService.deleteAsset(asset['id'] as int);
                                      await _load();
                                    }),
                            icon: const Icon(Icons.delete),
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
              ..._savingEntries.take(7).map((entry) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${_currency.format(entry['amount'])} ${entry['currency']}'),
                    subtitle: Text('${entry['created_at']}'),
                  )),
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
                        LinearProgressIndicator(value: progress),
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
                value: _notificationInterval,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t(context, 'app_title')),
        actions: [
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
              child: Column(
                children: [
                  _sectionCard(
                    title: AppStrings.t(context, 'members'),
                    actions: [
                      IconButton(
                        onPressed: _busy ? null : _addMemberDialog,
                        icon: const Icon(Icons.person_add),
                      ),
                    ],
                    child: _memberSelector(),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
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
                ],
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.workspace_premium), label: 'Assets'),
          NavigationDestination(icon: Icon(Icons.savings), label: 'Savings/Goals'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'More'),
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
