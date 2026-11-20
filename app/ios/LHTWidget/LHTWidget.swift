// Widget màn hình chính iOS cho LHT Money (WidgetKit + SwiftUI).
// Cách thêm vào project (cần máy Mac + Xcode) — xem docs/WIDGET_IOS.md:
//   File > New > Target > Widget Extension, tên "LHTWidget", rồi thay nội dung file này.
//   Bật App Groups "group.vn.lht.money" cho cả Runner và LHTWidget.
// Dữ liệu do app Flutter ghi qua HomeWidget.saveWidgetData (lib/data/background.dart).

import SwiftUI
import WidgetKit

private let appGroup = "group.vn.lht.money"

struct LHTEntry: TimelineEntry {
    let date: Date
    let monthExpense: String
    let monthIncome: String
    let loveDays: String
    let todayEvents: String
}

struct LHTProvider: TimelineProvider {
    func placeholder(in context: Context) -> LHTEntry {
        LHTEntry(date: Date(), monthExpense: "1.250.000 ₫", monthIncome: "15.000.000 ₫", loveDays: "520 ngày", todayEvents: "09:00 Họp nhóm")
    }

    func getSnapshot(in context: Context, completion: @escaping (LHTEntry) -> Void) {
        completion(read())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LHTEntry>) -> Void) {
        // App gọi HomeWidget.updateWidget mỗi khi dữ liệu đổi; thêm làm mới định kỳ 30 phút.
        completion(Timeline(entries: [read()], policy: .after(Date().addingTimeInterval(1800))))
    }

    private func read() -> LHTEntry {
        let d = UserDefaults(suiteName: appGroup)
        return LHTEntry(
            date: Date(),
            monthExpense: d?.string(forKey: "month_expense") ?? "0 ₫",
            monthIncome: d?.string(forKey: "month_income") ?? "0 ₫",
            loveDays: d?.string(forKey: "love_days") ?? "",
            todayEvents: d?.string(forKey: "today_events") ?? "Không có lịch trình"
        )
    }
}

struct LHTWidgetView: View {
    var entry: LHTEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Chi tháng này").font(.caption).foregroundStyle(.secondary)
            Text(entry.monthExpense).font(.title3).bold().foregroundStyle(.red)
            if family != .systemSmall {
                Text("Thu: \(entry.monthIncome)").font(.caption)
                Divider()
                Text(entry.todayEvents).font(.caption).lineLimit(3)
            }
            Spacer()
            if !entry.loveDays.isEmpty {
                Label(entry.loveDays, systemImage: "heart.fill").font(.caption).foregroundStyle(.pink)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "lhtmoney:///"))
    }
}

@main
struct LHTWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LHTWidget", provider: LHTProvider()) { entry in
            LHTWidgetView(entry: entry)
        }
        .configurationDisplayName("LHT Money")
        .description("Chi tiêu tháng, lịch trình hôm nay, ngày yêu")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
