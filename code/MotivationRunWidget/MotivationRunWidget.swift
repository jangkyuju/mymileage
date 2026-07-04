//
//  MotivationRunWidget.swift
//  MotivationRunWidget
//

import WidgetKit
import SwiftUI

// MARK: - 타임라인 엔트리

struct SimpleEntry: TimelineEntry {
    let date: Date
    let stats: MonthlyStats?
    let themeAccent: ThemeAccent
    let themeBackground: ThemeBackground
    let distanceUnit: DistanceUnit
    let language: AppLanguage
    let bgImageData: Data?
    let bgIsDark: Bool
    let widgetDesign: WidgetDesign
    let isPro: Bool
    let runFrequency: RunFrequency
}

// MARK: - 공통 계산

private struct WidgetStats {
    let currentValue: Double
    let goalTarget: Double
    let goalType: GoalType
    let remaining: Double
    let progress: Double
    let remainingDays: Int
    let perSessionValue: Double
    let frequency: RunFrequency
    let distanceUnit: DistanceUnit
    let language: AppLanguage

    init(stats: MonthlyStats?, date: Date, distanceUnit: DistanceUnit, language: AppLanguage, runFrequency: RunFrequency) {
        let cal = Calendar.current
        self.distanceUnit = distanceUnit
        self.language     = language

        goalType   = stats?.goalType  ?? .distance
        goalTarget = stats?.goalTarget ?? goalType.defaultTarget

        switch goalType {
        case .distance:
            currentValue = (stats?.totalDistanceKm ?? 0) * distanceUnit.conversionFromKm
        case .calories:
            currentValue = stats?.totalCalories ?? 0
        case .duration:
            currentValue = (stats?.totalDurationMinutes ?? 0) / 60
        }

        remaining = max(goalTarget - currentValue, 0)
        progress  = goalTarget > 0 ? min(currentValue / goalTarget, 1.0) : 0

        let days = remainingDaysInMonth(from: date, calendar: cal)
        remainingDays = days

        frequency = runFrequency
        let sessions = frequency.expectedSessions(remainingDays: days)
        perSessionValue = remaining / sessions
    }

    func format(_ value: Double) -> String {
        switch goalType {
        case .distance: return String(format: "%.1f", value)
        case .calories: return String(format: "%.0f", value)
        case .duration: return String(format: "%.1f", value)
        }
    }

    /// 잠금화면용 짧은 포맷 (소수점 없이 또는 한 자리)
    func shortFormat(_ value: Double) -> String {
        switch goalType {
        case .distance:
            return value >= 100 ? String(format: "%.0f", value) : String(format: "%.1f", value)
        case .calories:
            return String(format: "%.0f", value)
        case .duration:
            return String(format: "%.1f", value)
        }
    }

    var unitString: String { goalType.displayUnit(distanceUnit: distanceUnit, lang: language) }

    var goalLabel: String {
        switch goalType {
        case .distance: return "\(Int(goalTarget))\(distanceUnit.symbol)"
        case .calories: return "\(Int(goalTarget))kcal"
        case .duration: return "\(Int(goalTarget))\(L(.durationUnit, language))"
        }
    }

    var daysLeftString: String { String(format: L(.daysLeftFmt, language), remainingDays) }
}

// MARK: - 공통 색상 계산

private struct WidgetColors {
    let fgMain: Color
    let fgSub: Color
    let fgAccent: Color
    let fgOnBar: Color
    let barTrack: Color
    let dotColor: Color

    init(entry: SimpleEntry) {
        let hasBg  = entry.isPro && entry.bgImageData != nil
        let isDark = entry.bgIsDark
        let accentColor = entry.themeBackground.isDark ? entry.themeAccent.colorDark : entry.themeAccent.color
        fgMain   = hasBg ? (isDark ? .white : .black) : entry.themeBackground.mainText
        fgSub    = hasBg ? (isDark ? .white.opacity(0.7) : .black.opacity(0.6)) : entry.themeBackground.subText
        fgAccent = hasBg ? (isDark ? .white : .black) : accentColor
        fgOnBar  = hasBg ? (isDark ? .black : .white) : entry.themeAccent.foregroundColor
        barTrack = hasBg ? (isDark ? .white.opacity(0.3) : .black.opacity(0.3)) : entry.themeBackground.grayBg
        dotColor = hasBg ? (isDark ? .white.opacity(0.5) : .black.opacity(0.4)) : entry.themeBackground.grayBg
    }
}

// MARK: - Minimal 위젯

struct MinimalWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        let s = WidgetStats(stats: entry.stats, date: entry.date,
                            distanceUnit: entry.distanceUnit, language: entry.language,
                            runFrequency: entry.runFrequency)
        let c = WidgetColors(entry: entry)
        let lang = entry.language

        let dateFmt: DateFormatter = {
            let f = DateFormatter()
            f.locale = lang.locale
            f.dateFormat = L(.longDateFormat, lang)
            return f
        }()

        VStack {
            HStack {
                Text(dateFmt.string(from: entry.date))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(c.fgSub)
                Spacer()
            }

            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(s.format(s.currentValue))
                    .font(.system(size: 48, weight: .black))
                    .foregroundColor(c.fgMain)
                    .minimumScaleFactor(0.5)
                Text(s.unitString)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(c.fgSub)
            }

            Spacer()
        }
        .padding(16)
        .widgetBackground(entry: entry)
    }
}

// MARK: - Compact 위젯

struct CompactWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        let s = WidgetStats(stats: entry.stats, date: entry.date,
                            distanceUnit: entry.distanceUnit, language: entry.language,
                            runFrequency: entry.runFrequency)
        let c = WidgetColors(entry: entry)
        let lang = entry.language

        let dateFmt: DateFormatter = {
            let f = DateFormatter()
            f.locale = lang.locale
            f.dateFormat = L(.longDateFormat, lang)
            return f
        }()

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(dateFmt.string(from: entry.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(c.fgSub)
                Spacer()
                Text(s.daysLeftString)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(c.fgAccent)
            }

            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(s.format(s.currentValue))
                    .font(.system(size: 40, weight: .black))
                    .foregroundColor(c.fgMain)
                    .minimumScaleFactor(0.5)
                Text(s.unitString)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(c.fgSub)
            }
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(c.barTrack)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(c.fgAccent)
                            .frame(width: geo.size.width * CGFloat(s.progress))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 8)

                Text("\(Int(s.progress * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(c.fgAccent)
                    .fixedSize()
            }
        }
        .padding(16)
        .widgetBackground(entry: entry)
    }
}

// MARK: - Balanced 위젯

struct BalancedWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        let s = WidgetStats(stats: entry.stats, date: entry.date,
                            distanceUnit: entry.distanceUnit, language: entry.language,
                            runFrequency: entry.runFrequency)
        let c = WidgetColors(entry: entry)
        let lang = entry.language

        let dateFmt: DateFormatter = {
            let f = DateFormatter()
            f.locale = lang.locale
            f.dateFormat = L(.longDateFormat, lang)
            return f
        }()

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(dateFmt.string(from: entry.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(c.fgSub)
                Spacer()
                Text(s.daysLeftString)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(c.fgAccent)
            }

            Spacer()

            HStack(alignment: .bottom) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(s.format(s.currentValue))
                        .font(.system(size: 40, weight: .black))
                        .foregroundColor(c.fgMain)
                        .minimumScaleFactor(0.5)
                    Text(s.unitString)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(c.fgSub)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L(.widgetTotalGoal, lang))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(c.fgSub)
                    Text(s.goalLabel)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(c.fgMain)
                }
            }
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(c.barTrack)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(c.fgAccent)
                            .frame(width: geo.size.width * CGFloat(s.progress))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 8)

                Text("\(Int(s.progress * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(c.fgAccent)
                    .fixedSize()
            }
        }
        .padding(16)
        .widgetBackground(entry: entry)
    }
}

// MARK: - Medium 위젯 (Complete)

struct MediumWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        let s    = WidgetStats(stats: entry.stats, date: entry.date,
                               distanceUnit: entry.distanceUnit, language: entry.language,
                               runFrequency: entry.runFrequency)
        let lang = entry.language
        let c    = WidgetColors(entry: entry)

        let longFmt: DateFormatter = {
            let f = DateFormatter()
            f.locale = lang.locale
            f.dateFormat = L(.longDateFormat, lang)
            return f
        }()

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(longFmt.string(from: entry.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(c.fgSub)
                Text("\u{00B7}")
                    .foregroundColor(c.dotColor)
                Text(s.daysLeftString)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(c.fgAccent)
                Spacer()
            }
            .padding(.bottom, 10)

            HStack(alignment: .center, spacing: 14) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(s.format(s.currentValue))
                        .font(.system(size: 38, weight: .black))
                        .foregroundColor(c.fgMain)
                        .minimumScaleFactor(0.6)
                    Text(s.unitString)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(c.fgSub)
                }
                .fixedSize()

                thickProgressBar(progress: s.progress, height: 28,
                                 accent: c.fgAccent, accentFg: c.fgOnBar,
                                 gray: c.barTrack)
            }
            .padding(.bottom, 14)

            HStack(spacing: 0) {
                statItem(label: L(.widgetTotalGoal, lang),
                         value: s.format(s.goalTarget), unit: s.unitString,
                         accent: c.fgAccent, sub: c.fgSub)
                statItem(label: "\(L(.widgetRemainingPrefix, lang)) \(s.unitString)",
                         value: s.format(s.remaining), unit: s.unitString,
                         accent: c.fgAccent, sub: c.fgSub)
                statItem(label: s.frequency.localizedRunLabel(lang: lang),
                         value: s.format(s.perSessionValue),
                         unit: "\(s.unitString)\(L(.widgetPerRunUnit, lang))",
                         accent: c.fgAccent, sub: c.fgSub)
            }
        }
        .padding(16)
        .widgetBackground(entry: entry)
    }

    private func statItem(label: String, value: String, unit: String,
                          accent: Color, sub: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(sub)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(accent)
                Text(unit)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 위젯 배경 모디파이어

extension View {
    @ViewBuilder
    func widgetBackground(entry: SimpleEntry) -> some View {
        if entry.isPro,
           let data = entry.bgImageData,
           let uiImage = UIImage(data: data) {
            // 어두운 배경: 약간 더 어둡게 / 밝은 배경: 약간 더 밝게 (가독성)
            let overlay: Color = entry.bgIsDark
                ? Color.black.opacity(0.2)
                : Color.white.opacity(0.2)
            self.containerBackground(for: .widget) {
                ZStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    overlay
                }
            }
        } else {
            self.containerBackground(entry.themeBackground.cardBg, for: .widget)
        }
    }
}

// MARK: - 잠금화면 위젯: Circular (1x1)

struct AccessoryCircularView: View {
    let entry: SimpleEntry

    var body: some View {
        let s = WidgetStats(stats: entry.stats, date: entry.date,
                            distanceUnit: entry.distanceUnit, language: entry.language,
                            runFrequency: entry.runFrequency)

        Gauge(value: s.progress) {
            Image(systemName: "figure.run")
                .font(.system(size: 10))
        } currentValueLabel: {
            VStack(spacing: 0) {
                Text(s.shortFormat(s.currentValue))
                    .font(.system(size: 11, weight: .bold))
                    .minimumScaleFactor(0.5)
                Text(s.unitString)
                    .font(.system(size: 7, weight: .medium))
                    .minimumScaleFactor(0.5)
            }
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - 잠금화면 위젯: Rectangular (2x1)

struct AccessoryRectangularView: View {
    let entry: SimpleEntry

    var body: some View {
        let s = WidgetStats(stats: entry.stats, date: entry.date,
                            distanceUnit: entry.distanceUnit, language: entry.language,
                            runFrequency: entry.runFrequency)

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "figure.run")
                    .font(.system(size: 10, weight: .semibold))
                Text(s.shortFormat(s.currentValue) + " / " + s.shortFormat(s.goalTarget) + " " + s.unitString)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Gauge(value: s.progress) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)

            HStack {
                Text("\(Int(s.progress * 100))%")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text(s.daysLeftString)
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - 두꺼운 진행 바

@ViewBuilder
private func thickProgressBar(progress: Double, height: CGFloat,
                               accent: Color, accentFg: Color, gray: Color) -> some View {
    GeometryReader { geo in
        let filledWidth = geo.size.width * CGFloat(progress)
        let pct = "\(Int(progress * 100))%"
        let textWidth: CGFloat = 40

        ZStack(alignment: .leading) {
            // 배경 + 채움 (클리핑 적용)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(gray)
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(accent)
                    .frame(width: filledWidth, height: height)
            }
            .clipShape(RoundedRectangle(cornerRadius: height / 2))

            // 퍼센트 텍스트 (클리핑 미적용)
            if filledWidth > textWidth + 8 {
                let centerX = filledWidth / 2 - textWidth / 2
                Text(pct)
                    .font(.system(size: height * 0.42, weight: .bold))
                    .foregroundColor(accentFg)
                    .frame(width: textWidth)
                    .offset(x: centerX)
            } else {
                let safeOffset = min(filledWidth + 6, geo.size.width - textWidth)
                Text(pct)
                    .font(.system(size: height * 0.42, weight: .bold))
                    .foregroundColor(accent)
                    .frame(width: textWidth)
                    .offset(x: safeOffset)
            }
        }
    }
    .frame(height: height)
}

// MARK: - 타임라인 프로바이더

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), stats: nil,
                    themeAccent: .blue, themeBackground: .white,
                    distanceUnit: .km, language: .english,
                    bgImageData: nil, bgIsDark: false,
                    widgetDesign: .complete, isPro: false,
                    runFrequency: .everyOther)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> SimpleEntry {
        let mgr = SharedDataManager.shared
        // 잠금화면 위젯에서는 배경 이미지 불필요 — Home Screen 위젯만 로드
        let bgData: Data? = {
            guard mgr.hasWidgetBackgroundImage() else { return nil }
            return mgr.loadWidgetBackgroundImageData()
        }()
        return SimpleEntry(
            date: Date(),
            stats: mgr.getMonthlyStats(),
            themeAccent: mgr.getThemeAccent(),
            themeBackground: mgr.getThemeBackground(),
            distanceUnit: mgr.getDistanceUnit(),
            language: mgr.getLanguage(),
            bgImageData: bgData,
            bgIsDark: mgr.isWidgetBgDark(),
            widgetDesign: mgr.getWidgetDesign(),
            isPro: mgr.getIsPro(),
            runFrequency: mgr.getRunFrequency()
        )
    }
}

// MARK: - 위젯 진입점 (WidgetBundle로 여러 위젯 등록)

@main
struct MotivationRunWidgetBundle: WidgetBundle {
    var body: some Widget {
        HomeScreenWidget()
        LockScreenWidget()
    }
}

// MARK: - 홈 화면 위젯

struct HomeScreenWidget: Widget {
    let kind: String = "MotivationRunWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MotivationRunWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MyMileage")
        .description("Check your monthly running progress.")
        .supportedFamilies([.systemMedium])
    }
}

struct MotivationRunWidgetEntryView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .systemMedium {
            switch entry.widgetDesign {
            case .minimal:  MinimalWidgetView(entry: entry)
            case .compact:  CompactWidgetView(entry: entry)
            case .balanced: BalancedWidgetView(entry: entry)
            case .complete: MediumWidgetView(entry: entry)
            }
        }
    }
}

// MARK: - 잠금화면 위젯

struct LockScreenWidget: Widget {
    let kind: String = "MotivationRunLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(L(.lockWidgetName, SharedDataManager.shared.getLanguage()))
        .description(L(.lockWidgetDescription, SharedDataManager.shared.getLanguage()))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct LockScreenWidgetEntryView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if entry.isPro {
            switch family {
            case .accessoryCircular:
                AccessoryCircularView(entry: entry)
            case .accessoryRectangular:
                AccessoryRectangularView(entry: entry)
            default:
                EmptyView()
            }
        } else {
            // Pro 미구매 시 잠금화면 위젯에 안내 표시
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                }
                .containerBackground(.clear, for: .widget)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text("MyMileage Pro")
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                    }
                    Text(L(.lockWidgetProRequired, entry.language))
                        .font(.system(size: 11))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .containerBackground(.clear, for: .widget)
            default:
                EmptyView()
            }
        }
    }
}
