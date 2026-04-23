import 'package:flutter/material.dart';

import '../services/api_service.dart';

class PriceAlertsScreen extends StatefulWidget {
  const PriceAlertsScreen({
    super.key,
    required this.apiService,
    required this.locale,
  });

  final ApiService apiService;
  final Locale locale;

  @override
  State<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends State<PriceAlertsScreen> {
  bool get _isAr => widget.locale.languageCode == 'ar';

  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await widget.apiService.getPriceAlerts();
    if (mounted) setState(() { _alerts = rows; _loading = false; });
  }

  Future<void> _delete(int id) async {
    await widget.apiService.deletePriceAlert(id);
    _load();
  }

  Future<void> _toggleActive(Map<String, dynamic> alert) async {
    final newActive = (alert['active'] as int?) == 1 ? false : true;
    await widget.apiService.updatePriceAlert(
      alert['id'] as int,
      {'active': newActive},
    );
    _load();
  }

  Future<void> _showAddDialog() async {
    String karat = '21k';
    String direction = 'above';
    final controller = TextEditingController();

    final karatOptions = ['21k', '24k', 'ounce'];
    final karatLabels = {
      '21k': _isAr ? 'عيار 21' : '21K',
      '24k': _isAr ? 'عيار 24' : '24K',
      'ounce': _isAr ? 'أونصة' : 'Ounce',
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(_isAr ? 'تنبيه سعر جديد' : 'New Price Alert'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isAr ? 'العيار' : 'Karat',
                  style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: karatOptions
                    .map((k) => ButtonSegment(
                        value: k, label: Text(karatLabels[k]!)))
                    .toList(),
                selected: {karat},
                onSelectionChanged: (s) =>
                    setDialogState(() => karat = s.first),
              ),
              const SizedBox(height: 16),
              Text(_isAr ? 'الاتجاه' : 'Direction',
                  style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'above',
                      label: Text(_isAr ? 'يتجاوز' : 'Above')),
                  ButtonSegment(
                      value: 'below',
                      label: Text(_isAr ? 'ينخفض عن' : 'Below')),
                ],
                selected: {direction},
                onSelectionChanged: (s) =>
                    setDialogState(() => direction = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _isAr ? 'السعر المستهدف' : 'Target price',
                  suffixText: karat == 'ounce' ? '\$' : 'EGP',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_isAr ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final price = double.tryParse(controller.text.trim());
                if (price == null || price <= 0) return;
                try {
                  await widget.apiService.createPriceAlert(
                    karat: karat,
                    targetPrice: price,
                    direction: direction,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(_isAr
                          ? 'تعذّر الحفظ: $e'
                          : 'Save failed: $e'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              child: Text(_isAr ? 'إضافة' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gold = Color(0xFFD4AF37);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isAr ? 'تنبيهات الأسعار' : 'Price Alerts'),
        backgroundColor: gold,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: gold,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        _isAr
                            ? 'لا توجد تنبيهات\nاضغط + لإضافة تنبيه جديد'
                            : 'No alerts yet\nTap + to add one',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  itemCount: _alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _AlertTile(
                    alert: _alerts[i],
                    isAr: _isAr,
                    onDelete: () => _delete(_alerts[i]['id'] as int),
                    onToggle: () => _toggleActive(_alerts[i]),
                  ),
                ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.isAr,
    required this.onDelete,
    required this.onToggle,
  });

  final Map<String, dynamic> alert;
  final bool isAr;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  String get _karatLabel {
    final k = alert['karat'] as String;
    if (k == 'ounce') return isAr ? 'الأونصة' : 'Ounce';
    if (k == '21k') return isAr ? 'عيار 21' : '21K';
    return isAr ? 'عيار 24' : '24K';
  }

  String get _dirLabel {
    final d = alert['direction'] as String;
    return d == 'above'
        ? (isAr ? 'يتجاوز' : 'above')
        : (isAr ? 'ينخفض عن' : 'below');
  }

  String get _currency {
    return alert['karat'] == 'ounce' ? '\$' : (isAr ? 'جنيه' : 'EGP');
  }

  bool get _active => (alert['active'] as int?) == 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = (alert['target_price'] as num?)?.toStringAsFixed(0) ?? '-';

    return Dismissible(
      key: ValueKey(alert['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(
            alert['direction'] == 'above'
                ? Icons.trending_up
                : Icons.trending_down,
            color: alert['direction'] == 'above'
                ? Colors.green
                : Colors.red,
          ),
          title: Text('$_karatLabel $_dirLabel $price $_currency'),
          subtitle: _active
              ? Text(isAr ? 'نشط' : 'Active',
                  style: const TextStyle(color: Colors.green))
              : Text(
                  alert['last_triggered_at'] != null
                      ? (isAr ? 'تم الإطلاق' : 'Triggered')
                      : (isAr ? 'غير نشط' : 'Inactive'),
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant)),
          trailing: Switch(
            value: _active,
            onChanged: (_) => onToggle(),
            activeColor: const Color(0xFFD4AF37),
          ),
        ),
      ),
    );
  }
}
