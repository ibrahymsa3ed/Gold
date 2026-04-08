import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class GoldScraper {
  static const _sourceUrl = 'https://edahabapp.com/';
  static const _telegramUrl = 'https://t.me/s/eDahabApp';
  static const _exchangeRateUrl = 'https://open.er-api.com/v6/latest/USD';
  static const _carats = ['24', '21', '18', '14'];

  static double? _parseNumber(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized =
        value.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '');
    final parsed = double.tryParse(normalized);
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  /// Primary scraper: tries eDahab website first, falls back to Telegram channel.
  static Future<Map<String, dynamic>> scrapeGoldPrices() async {
    try {
      final response = await http
          .get(
            Uri.parse(_sourceUrl),
            headers: {'User-Agent': 'InstaGold/2.0'},
          )
          .timeout(const Duration(seconds: 20));

      final result = _parsePrices(response.body);
      final carats = result['carats'] as Map? ?? {};
      if (carats.isNotEmpty) {
        result['source'] = 'edahab-web';
        return result;
      }
    } catch (_) {}

    return _scrapeTelegramFallback();
  }

  /// Fallback: scrape the public Telegram channel web preview.
  /// The channel posts prices in a consistent emoji format:
  ///   🔸 عيار 24: 8274 جنيه
  ///   🔸 الجنيه الذهب: 57920 جنيه
  static Future<Map<String, dynamic>> _scrapeTelegramFallback() async {
    final response = await http
        .get(
          Uri.parse(_telegramUrl),
          headers: {'User-Agent': 'InstaGold/2.0'},
        )
        .timeout(const Duration(seconds: 20));

    return _parseTelegramPrices(response.body);
  }

  static Map<String, dynamic> _parseTelegramPrices(String htmlContent) {
    final document = parse(htmlContent);
    final carats = <String, dynamic>{};
    double? goldPoundPrice;
    double? ouncePrice;

    final messages = document.querySelectorAll('.tgme_widget_message_text');
    for (final msg in messages.reversed) {
      final text = msg.text ?? '';
      if (!text.contains('أسعار الذهب')) continue;

      final lines = text.split('\n').map((l) => l.trim()).toList();
      for (final line in lines) {
        for (final carat in ['24', '21', '18']) {
          if (line.contains('عيار $carat') && !carats.containsKey(carat)) {
            final match = RegExp(r'(\d[\d.,]*)').firstMatch(
              line.substring(line.indexOf('عيار $carat')),
            );
            if (match != null) {
              final price = _parseNumber(match.group(1));
              if (price != null) {
                carats[carat] = {'buy': price, 'sell': price};
              }
            }
          }
        }

        if (line.contains('الجنيه الذهب') && goldPoundPrice == null) {
          final match = RegExp(r'(\d[\d.,]*)').firstMatch(
            line.substring(line.indexOf('الجنيه')),
          );
          if (match != null) goldPoundPrice = _parseNumber(match.group(1));
        }

        if (line.contains('الأونصة') && ouncePrice == null) {
          final match = RegExp(r'(\d[\d.,]*)').firstMatch(
            line.substring(line.indexOf('الأونصة')),
          );
          if (match != null) ouncePrice = _parseNumber(match.group(1));
        }
      }

      if (carats.isNotEmpty) break;
    }

    return {
      'carats': carats,
      'goldPoundPrice': goldPoundPrice,
      'ouncePrice': ouncePrice,
      'updatedAt': DateTime.now().toIso8601String(),
      'currency': 'EGP',
      'source': 'telegram-edahab',
    };
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
        final val =
            numberFonts.isNotEmpty ? _parseNumber(numberFonts.first.text) : null;
        if (val != null) goldPoundPrice = val;
      }

      if (label.contains('الأوقية') || label.contains('الأونصة')) {
        final val =
            numberFonts.isNotEmpty ? _parseNumber(numberFonts.first.text) : null;
        if (val != null) ouncePrice = val;
      }
    }

    if (carats.isEmpty) {
      final ldJsonEl =
          document.querySelector('script[type="application/ld+json"]');
      if (ldJsonEl != null) {
        try {
          final data = jsonDecode(ldJsonEl.text);
          final props = data['additionalProperty'] as List? ?? [];
          for (final prop in props) {
            for (final carat in _carats) {
              if (prop['name']?.toString().contains('عيار $carat') == true &&
                  prop['name']?.toString().contains('بيع') == true) {
                carats[carat] ??= {};
                (carats[carat] as Map)['sell'] =
                    _parseNumber(prop['value']?.toString());
                (carats[carat] as Map)['buy'] ??=
                    (carats[carat] as Map)['sell'];
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
      final response = await http
          .get(Uri.parse(_exchangeRateUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['rates']?['EGP'] as num?)?.toDouble();
      }
    } catch (_) {}
    return null;
  }
}
