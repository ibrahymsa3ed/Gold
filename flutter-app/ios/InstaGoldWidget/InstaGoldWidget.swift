import WidgetKit
import SwiftUI

private let appGroupId = "group.com.ibrahym.goldtracker"

struct GoldPriceEntry: TimelineEntry {
    let date: Date
    let price21k: Double?
    let price24k: Double?
    let priceOunce: Double?
    let updatedAt: String?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> GoldPriceEntry {
        GoldPriceEntry(
            date: Date(),
            price21k: 8200,
            price24k: 9400,
            priceOunce: 2350,
            updatedAt: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (GoldPriceEntry) -> ()) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoldPriceEntry>) -> ()) {
        let entry = loadEntry()
        // Refresh every 30 minutes
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }

    private func loadEntry() -> GoldPriceEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let p21 = defaults?.object(forKey: "price_21k") as? Double
        let p24 = defaults?.object(forKey: "price_24k") as? Double
        let pOunce = defaults?.object(forKey: "price_ounce") as? Double
        let updatedAt = defaults?.string(forKey: "updated_at")
        return GoldPriceEntry(
            date: Date(),
            price21k: p21,
            price24k: p24,
            priceOunce: pOunce,
            updatedAt: updatedAt
        )
    }
}

struct InstaGoldWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    private let goldGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 232/255, green: 205/255, blue: 90/255),
            Color(red: 212/255, green: 175/255, blue: 55/255),
            Color(red: 184/255, green: 150/255, blue: 46/255)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let darkBg = Color(red: 11/255, green: 11/255, blue: 13/255)

    var body: some View {
        ZStack {
            darkBg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("InstaGold")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(goldGradient)
                    Spacer()
                    Text("Gold")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
                Divider().background(Color.white.opacity(0.08))

                priceRow(label: "21K", value: entry.price21k, suffix: "EGP")
                priceRow(label: "24K", value: entry.price24k, suffix: "EGP")
                if family != .systemSmall {
                    priceRow(label: "Ounce", value: entry.priceOunce, suffix: "USD", prefix: "$")
                }

                Spacer(minLength: 0)
                if let updated = entry.updatedAt, let formatted = formatTime(updated) {
                    Text("Updated \(formatted)")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            .padding(12)
        }
        .containerBackground(for: .widget) { darkBg }
    }

    private func priceRow(label: String, value: Double?, suffix: String, prefix: String = "") -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
            Spacer()
            if let v = value {
                Text("\(prefix)\(Int(v))")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(goldGradient)
                Text(suffix)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                Text("—")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.gray)
            }
        }
    }

    private func formatTime(_ iso: String) -> String? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let d = date else { return nil }
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: d)
    }
}

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
