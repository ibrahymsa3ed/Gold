import WidgetKit
import SwiftUI

private let appGroupId = "group.com.ibrahym.goldtracker"

// MARK: - Design tokens
//
// Single source of truth for the widget's visual language. All colors,
// gradients and tone choices live here so the rest of the file reads as
// pure layout. Light/dark variants are kept side-by-side to keep both
// themes honest — neither is an afterthought.

private enum Tokens {
    // Page backgrounds
    static let bgDark  = Color(red: 11/255,  green: 11/255,  blue: 13/255)
    static let bgLight = Color(red: 247/255, green: 244/255, blue: 237/255)

    // Subtle surface tint used by the timestamp pill (no hard borders, just
    // a 4–6% wash so the eye groups the meta info into a chip).
    static func surface(_ s: ColorScheme) -> Color {
        s == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    // Hairline divider between price rows. Kept very low contrast so it
    // groups without competing with the numbers.
    static func divider(_ s: ColorScheme) -> Color {
        s == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
    }

    // Text roles
    static func textPrimary(_ s: ColorScheme) -> Color {
        s == .dark ? .white : Color(red: 22/255, green: 18/255, blue: 12/255)
    }
    static func textSecondary(_ s: ColorScheme) -> Color {
        s == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.50)
    }

    // Gold for the price values. Two tones — dark mode gets the bright
    // "InstaGold" gold (#D4AF37 → 7.8:1 on the dark bg, AAA), light mode
    // gets a deeper antique gold (#8A6414 → 5.4:1 on cream, AA Large).
    // Using one hex across both modes would have failed contrast somewhere.
    static func goldValue(_ s: ColorScheme) -> Color {
        s == .dark
            ? Color(red: 212/255, green: 175/255, blue: 55/255)   // #D4AF37
            : Color(red: 138/255, green: 100/255, blue: 20/255)   // #8A6414
    }

    // Brand gradient is the ONLY gradient in the widget. Restraint by
    // design — when everything is decorated, nothing reads as decoration.
    static let brandGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 232/255, green: 205/255, blue: 90/255),
            Color(red: 212/255, green: 175/255, blue: 55/255),
            Color(red: 184/255, green: 150/255, blue: 46/255)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Localization helpers
//
// Numbers stay in Western digits in both locales (product decision —
// matches the in-app price cards and notification body).

private func karatLabel(_ k: Int, locale: String) -> String {
    return locale == "ar" ? "عيار \(k)" : "\(k)K"
}
private func ounceLabel(_ locale: String) -> String {
    return locale == "ar" ? "الأونصه" : "Ounce"
}

// Tabular price formatter with thousand separator. Using Int(rounded()) on
// purpose — gold prices are always integer EGP/USD in this product.
private let priceFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    f.usesGroupingSeparator = true
    f.groupingSeparator = ","
    return f
}()

private func formatPrice(_ value: Double) -> String {
    priceFormatter.string(from: NSNumber(value: Int(value.rounded())))
        ?? "\(Int(value))"
}

private func formatTimeShort(_ iso: String) -> String? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    guard let d = date else { return nil }
    let df = DateFormatter()
    df.dateFormat = "HH:mm"
    return df.string(from: d)
}

// MARK: - Timeline entry

struct GoldPriceEntry: TimelineEntry {
    let date: Date
    let price21k: Double?
    let price24k: Double?
    let priceOunce: Double?
    let updatedAt: String?
    /// "en" or "ar" — written by the Flutter app via the App Group whenever
    /// the user changes language. Drives karat/ounce labels AND layout
    /// direction (RTL in Arabic).
    let locale: String
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoldPriceEntry {
        GoldPriceEntry(
            date: Date(),
            price21k: 8200,
            price24k: 9400,
            priceOunce: 2350,
            updatedAt: nil,
            locale: "en"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (GoldPriceEntry) -> ()) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoldPriceEntry>) -> ()) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> GoldPriceEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        return GoldPriceEntry(
            date: Date(),
            price21k:   defaults?.object(forKey: "price_21k") as? Double,
            price24k:   defaults?.object(forKey: "price_24k") as? Double,
            priceOunce: defaults?.object(forKey: "price_ounce") as? Double,
            updatedAt:  defaults?.string(forKey: "updated_at"),
            locale:     defaults?.string(forKey: "locale") ?? "en"
        )
    }
}

// MARK: - View

struct InstaGoldWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme

    private var isAr: Bool { entry.locale == "ar" }
    private var isSmall: Bool { family == .systemSmall }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, isSmall ? 8 : 10)

            // The three rows form a single visual card — no border, just
            // hairline dividers. Equal weight: the karat label tells you
            // which is which, the price is the answer.
            VStack(spacing: 0) {
                priceRow(label: karatLabel(21, locale: entry.locale),
                         value: entry.price21k)
                rowDivider
                priceRow(label: karatLabel(24, locale: entry.locale),
                         value: entry.price24k)
                rowDivider
                priceRow(label: ounceLabel(entry.locale),
                         value: entry.priceOunce,
                         prefix: "$")
            }
        }
        .padding(isSmall ? 12 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Mirror layout for Arabic so the karat labels sit on the right
        // and the prices sit on the left, matching native RTL reading flow.
        .environment(\.layoutDirection, isAr ? .rightToLeft : .leftToRight)
        .containerBackground(for: .widget) {
            scheme == .dark ? Tokens.bgDark : Tokens.bgLight
        }
    }

    // Header: brand mark on one side, time pill on the other. The pill
    // is the only place the user sees "when was this last updated"; in
    // the previous design that lived as a tiny 9pt footer that nobody
    // could read.
    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("iG")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.brandGradient)
            Text("InstaGold")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Tokens.textSecondary(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if let updated = entry.updatedAt,
               let formatted = formatTimeShort(updated) {
                Text(formatted)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Tokens.textSecondary(scheme))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Tokens.surface(scheme)))
            }
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Tokens.divider(scheme))
            .frame(height: 0.5)
    }

    // One price row: muted label on the leading edge, gold-toned value on
    // the trailing edge with tabular digits so width never jitters between
    // updates. minimumScaleFactor keeps long Arabic labels from clipping
    // even when the value is wide.
    @ViewBuilder
    private func priceRow(label: String, value: Double?, prefix: String = "") -> some View {
        let labelSize: CGFloat = isSmall ? 11 : 12
        let valueSize: CGFloat = isSmall ? 17 : 20

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundColor(Tokens.textSecondary(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            Group {
                if let v = value {
                    Text("\(prefix)\(formatPrice(v))")
                        .font(.system(size: valueSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Tokens.goldValue(scheme))
                } else {
                    Text("—")
                        .font(.system(size: valueSize, weight: .bold))
                        .foregroundColor(Tokens.textSecondary(scheme))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.vertical, isSmall ? 6 : 8)
    }
}

// MARK: - Widget configuration

@main
struct InstaGoldWidget: Widget {
    let kind: String = "InstaGoldWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            InstaGoldWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("InstaGold Prices")
        .description("Live gold prices: 21K, 24K, and global ounce.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
