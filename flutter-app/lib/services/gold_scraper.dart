import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class GoldScraper {
  static const _sourceUrl = 'https://edahabapp.com/';
  static const _exchangeRateUrl = 'https://open.er-api.com/v6/latest/USD';
  static const _carats = ['24', '21', '18', '14'];

  static double? _parseNumber(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '');
    final parsed = double.tryParse(normalized);
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  static Future<Map<String, dynamic>> scrapeGoldPrices() async {
    final response = await http.get(
      Uri.parse(_sourceUrl),
      headers: {'User-Agent': 'GoldFamilyApp/1.0'},
    ).timeout(const Duration(seconds: 20));

    return _parsePrices(response.body);
  }

  static Map<String, dynamic> _parsePrices(String htmlContent) {
    final document = parse(htmlContent);
    final carats = <String, dynamic>{};
    double? goldPoundPrice;
    double? ouncePrice;

    final priceItems = document.querySelectorAll('.price-item');
    for (final el in priceItems) {
      final span = el.querySelector('span');
      final label = span?.text.trim() ?? '';
      final numberFonts = el.querySelectorAll('.number-font');

      for (final carat in _carats) {
        if ((label.contains('عيار $carat') || label.contains(carat)) &&
            !carats.containsKey(carat)) {
          final values = <double?>[];
          for (final numEl in numberFonts) {
            values.add(_parseNumber(numEl.text));
          }
          final parentText = el.text;
          double? sell = values.isNotEmpty ? values[0] : null;
          double? buy = values.length >= 2 ? values[1] : values.firstOrNull;
          if (values.length >= 2 &&
              parentText.indexOf('شراء') < parentText.indexOf('بيع')) {
            buy = values[0];
            sell = values[1];
          }
          carats[carat] = {'buy': buy, 'sell': sell};
        }
      }

      if (label.contains('الجنيه الذهب')) {
        final val = numberFonts.isNotEmpty ? _parseNumber(numberFonts.first.text) : null;
        if (val != null) goldPoundPrice = val;
      }

      if (label.contains('الأوقية') || label.contains('الأونصة')) {
        final val = numberFonts.isNotEmpty ? _parseNumber(numberFonts.first.text) : null;
        if (val != null) ouncePrice = val;
      }
    }

    // Fallback: ld+json structured data
    if (carats.isEmpty) {
      final ldJsonEl = document.querySelector('script[type="application/ld+json"]');
      if (ldJsonEl != null) {
        try {
          final data = jsonDecode(ldJsonEl.text);
          final props = data['additionalProperty'] as List? ?? [];
          for (final prop in props) {
            for (final carat in _carats) {
              if (prop['name']?.toString().contains('عيار $carat') == true &&
                  prop['name']?.toString().contains('بيع') == true) {
                carats[carat] ??= {};
                (carats[carat] as Map)['sell'] = _parseNumber(prop['value']?.toString());
                (carats[carat] as Map)['buy'] ??= (carats[carat] as Map)['sell'];
              }
            }
          }
        } catch (_) {}
      }
    }

    return {
      'carats': carats,
      'goldPoundPrice': goldPoundPrice,
      'ouncePrice': ouncePrice,
      'updatedAt': DateTime.now().toIso8601String(),
      'currency': 'EGP',
    };
  }

  /// Fetch the official USD/EGP exchange rate for دولار الصاغه comparison.
  static Future<double?> fetchUsdEgpRate() async {
    try {
      final response = await http.get(
        Uri.parse(_exchangeRateUrl),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['rates']?['EGP'] as num?)?.toDouble();
      }
    } catch (_) {}
    return null;
  }
}
