//
//  ShareCardView.swift
//  MotivationRun
//
//  Share card templates: Monthly Dark (A), Goal Achieved Light (B),
//  Streak Amber (C), Neon Gradient (D), Retro Sunrise (H), Sport Red (I)
//  + Minimal White, Mono, Aqua, Ember, Mint, Split
//

import SwiftUI
import UIKit

// MARK: - ShareCardCategory

enum ShareCardCategory: String, CaseIterable {
    case all      = "All"
    case dark     = "Dark"
    case light    = "Light"
    case gradient = "Gradient"
    case minimal  = "Minimal"
    case streak   = "Streak"
}

// MARK: - ShareCardData

struct ShareCardData {
    let monthLabel: String          // e.g. "June 2026"
    let primaryValue: Double        // distance km / calories / hours
    let primaryUnit: String         // "km", "kcal", "hr"
    let goalTarget: Double
    let goalType: GoalType
    let isGoalAchieved: Bool
    let progressPercent: Double     // 0–1, clamped for display
    let sessionCount: Int
    let streak: Int
    let avgPerSession: Double
    let accentColor: Color
    // Component chart data (this month, day 1 → today)
    let dailyValues: [Double]       // per-day totals in primaryUnit units
    let cumulativeValues: [Double]  // running cumulative sum of dailyValues
}

// MARK: - ShareCardTemplate

enum ShareCardTemplate: String, CaseIterable {
    case monthlyDark    // A — free
    case goalLight      // B — free
    case streakAmber    // C — free
    case neonGradient   // D — Pro
    case retroSunrise   // H — Pro
    case sportRed       // I — Pro
    case minimalWhite   // 7 — free
    case mono           // 8 — free
    case aqua           // 9 — Pro
    case ember          // 10 — Pro
    case mint           // 11 — Pro
    case split          // 12 — Pro

    var isPro: Bool {
        switch self {
        case .monthlyDark, .goalLight, .streakAmber, .minimalWhite, .mono: return false
        case .neonGradient, .retroSunrise, .sportRed, .aqua, .ember, .mint, .split: return true
        }
    }

    var label: String {
        switch self {
        case .monthlyDark:  return "Monthly"
        case .goalLight:    return "Goal Hit"
        case .streakAmber:  return "Streak"
        case .neonGradient: return "Neon"
        case .retroSunrise: return "Retro"
        case .sportRed:     return "Sport"
        case .minimalWhite: return "Minimal"
        case .mono:         return "Mono"
        case .aqua:         return "Aqua"
        case .ember:        return "Ember"
        case .mint:         return "Mint"
        case .split:        return "Split"
        }
    }

    var previewIcon: String {
        switch self {
        case .monthlyDark:  return "chart.bar.fill"
        case .goalLight:    return "checkmark.seal.fill"
        case .streakAmber:  return "flame.fill"
        case .neonGradient: return "sparkles"
        case .retroSunrise: return "sun.horizon.fill"
        case .sportRed:     return "bolt.fill"
        case .minimalWhite: return "doc.text"
        case .mono:         return "square.filled.on.square"
        case .aqua:         return "drop.fill"
        case .ember:        return "flame"
        case .mint:         return "leaf.fill"
        case .split:        return "rectangle.split.2x1.fill"
        }
    }

    var category: ShareCardCategory {
        switch self {
        case .monthlyDark:  return .dark
        case .goalLight:    return .light
        case .streakAmber:  return .streak
        case .neonGradient: return .gradient
        case .retroSunrise: return .gradient
        case .sportRed:     return .dark
        case .minimalWhite: return .minimal
        case .mono:         return .minimal
        case .aqua:         return .gradient
        case .ember:        return .dark
        case .mint:         return .light
        case .split:        return .dark
        }
    }
}

// MARK: - ShareCardFormat

enum ShareCardFormat: String, CaseIterable {
    case story    // 9:16, 360×640 @3x → 1080×1920
    case square   // 1:1,  360×360 @3x → 1080×1080
    case portrait // 4:5, 360×450 @3x → 1080×1350 (Instagram feed default)

    var size: CGSize {
        switch self {
        case .story:    return CGSize(width: 360, height: 640)
        case .square:   return CGSize(width: 360, height: 360)
        case .portrait: return CGSize(width: 360, height: 450)
        }
    }

    var label: String {
        switch self {
        case .story:    return "Story"
        case .square:   return "Square"
        case .portrait: return "Portrait"
        }
    }

    var icon: String {
        switch self {
        case .story:    return "rectangle.portrait"
        case .square:   return "square"
        case .portrait: return "rectangle.portrait.fill"
        }
    }
}

// MARK: - ShareCardView (router)

struct ShareCardView: View {
    let data: ShareCardData
    let template: ShareCardTemplate
    let format: ShareCardFormat

    var body: some View {
        Group {
            switch template {
            case .monthlyDark:  CardMonthlyDark(data: data, format: format)
            case .goalLight:    CardGoalLight(data: data, format: format)
            case .streakAmber:  CardStreakAmber(data: data, format: format)
            case .neonGradient: CardNeonGradient(data: data, format: format)
            case .retroSunrise: CardRetroSunrise(data: data, format: format)
            case .sportRed:     CardSportRed(data: data, format: format)
            case .minimalWhite: CardMinimalWhite(data: data, format: format)
            case .mono:         CardMono(data: data, format: format)
            case .aqua:         CardAqua(data: data, format: format)
            case .ember:        CardEmber(data: data, format: format)
            case .mint:         CardMint(data: data, format: format)
            case .split:        CardSplit(data: data, format: format)
            }
        }
        .frame(width: format.size.width, height: format.size.height)
        .clipped()
    }
}

// MARK: - ImageRenderer

@MainActor
enum ShareCardRenderer {
    static func render(
        data: ShareCardData,
        template: ShareCardTemplate,
        format: ShareCardFormat
    ) -> UIImage? {
        // Export는 고정 사이즈로 렌더링 — 사용자 Dynamic Type 설정의 영향을 받지 않는다.
        let view = ShareCardView(data: data, template: template, format: format)
            .environment(\.dynamicTypeSize, .large)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}

// MARK: - Shared helpers

private extension Double {
    var cardFormatted: String {
        if self >= 100 || truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded()))"
        }
        return String(format: "%.1f", self)
    }
    var cardFormattedShort: String { // no decimal, always
        "\(Int(rounded()))"
    }
}

private struct StatItem: View {
    let value: String
    let label: String
    let textColor: Color
    let labelColor: Color
    var valueSize: CGFloat = 22

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.pretendard(.semiBold, size: valueSize))
                .foregroundColor(textColor)
            Text(label.uppercased())
                .font(.pretendard(.medium, size: 10))
                .foregroundColor(labelColor)
                .tracking(0.8)
        }
    }
}

private struct ProgressBar: View {
    let percent: Double
    let fillColor: Color
    let trackColor: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(trackColor)
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(fillColor)
                    .frame(width: geo.size.width * min(max(percent, 0), 1), height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - A · Monthly Dark

private struct CardMonthlyDark: View {
    let data: ShareCardData
    let format: ShareCardFormat

    private var isStory: Bool   { format == .story }
    private var isPortrait: Bool { format == .portrait }
    private var isTall: Bool    { isStory || isPortrait }
    private let bg = Color(hex: "#0a0a0a")

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Top row
                HStack {
                    Text("MyMileage")
                        .font(.pretendard(.semiBold, size: 10))
                        .foregroundColor(Color(hex: "#444444"))
                        .tracking(1.5)
                    Spacer()
                    Text(data.monthLabel.uppercased())
                        .font(.pretendard(.medium, size: 11))
                        .foregroundColor(Color(hex: "#555555"))
                        .tracking(1)
                }

                Spacer()

                // Main number
                VStack(spacing: 4) {
                    Text(data.primaryValue.cardFormatted)
                        .font(.pretendard(.extraBold, size: isTall ? 88 : 72))
                        .foregroundColor(.white)
                        .tracking(-4)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("\(data.primaryUnit) this month")
                        .font(.pretendard(.regular, size: isTall ? 22 : 18))
                        .foregroundColor(Color(hex: "#666666"))
                        .tracking(1)
                }

                if isTall {
                    Spacer().frame(height: 24)
                    // Progress
                    VStack(spacing: 8) {
                        HStack {
                            Text("Monthly goal")
                                .font(.pretendard(.regular, size: 11))
                                .foregroundColor(Color(hex: "#555555"))
                            Spacer()
                            Text("\(data.primaryValue.cardFormatted) / \(data.goalTarget.cardFormattedShort) \(data.primaryUnit)")
                                .font(.pretendard(.regular, size: 11))
                                .foregroundColor(Color(hex: "#555555"))
                        }
                        ProgressBar(percent: data.progressPercent,
                                    fillColor: .white,
                                    trackColor: Color(hex: "#1e1e1e"))
                    }
                }

                Spacer()

                // Stats row
                HStack {
                    StatItem(value: "\(data.sessionCount)", label: "Runs",
                             textColor: .white, labelColor: Color(hex: "#444444"))
                    Spacer()
                    StatItem(value: data.avgPerSession.cardFormatted, label: "Avg \(data.primaryUnit)",
                             textColor: .white, labelColor: Color(hex: "#444444"))
                    Spacer()
                    StatItem(value: "\(data.streak)", label: "Streak",
                             textColor: .white, labelColor: Color(hex: "#444444"))
                }

                if isTall {
                    Spacer().frame(height: 24)
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "#333333")).frame(width: 4, height: 4)
                        Text("MyMileage")
                            .font(.pretendard(.medium, size: 10))
                            .foregroundColor(Color(hex: "#333333"))
                            .tracking(1)
                        Circle().fill(Color(hex: "#333333")).frame(width: 4, height: 4)
                    }
                }
            }
            .padding(isTall ? 32 : 28)
        }
    }
}

// MARK: - B · Goal Achieved Light

private struct CardGoalLight: View {
    let data: ShareCardData
    let format: ShareCardFormat

    private var isStory: Bool    { format == .story }
    private var isPortrait: Bool { format == .portrait }
    private var isTall: Bool     { isStory || isPortrait }
    private let bg = Color(hex: "#f5f5f5")
    private let textDark = Color(hex: "#0a0a0a")
    private let textMid = Color(hex: "#aaaaaa")

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Top row
                HStack {
                    // Goal Hit badge
                    Text("Goal Hit ✓")
                        .font(.pretendard(.bold, size: 9))
                        .foregroundColor(.white)
                        .tracking(1.5)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(textDark)
                        .clipShape(Capsule())
                    Spacer()
                    Text(data.monthLabel.uppercased())
                        .font(.pretendard(.medium, size: 11))
                        .foregroundColor(textMid)
                        .tracking(1)
                }

                Spacer()

                // Main
                VStack(spacing: 4) {
                    Text("THIS MONTH")
                        .font(.pretendard(.medium, size: 11))
                        .foregroundColor(textMid)
                        .tracking(2)
                    Text(data.primaryValue.cardFormatted)
                        .font(.pretendard(.extraBold, size: isTall ? 96 : 78))
                        .foregroundColor(textDark)
                        .tracking(-5)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(data.primaryUnit)
                        .font(.pretendard(.regular, size: isTall ? 24 : 20))
                        .foregroundColor(Color(hex: "#888888"))
                        .tracking(1)
                    if isTall {
                        Text("Goal was \(data.goalTarget.cardFormattedShort) \(data.primaryUnit)")
                            .font(.pretendard(.regular, size: 13))
                            .foregroundColor(textMid)
                            .padding(.top, 12)
                    }
                }

                Spacer()

                // Stats row
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(hex: "#e0e0e0"))
                        .frame(height: 1)
                    HStack {
                        Spacer()
                        StatItem(value: "\(data.sessionCount)", label: "Runs",
                                 textColor: textDark, labelColor: textMid,
                                 valueSize: isTall ? 22 : 18)
                        Spacer()
                        StatItem(value: "\(data.streak)", label: "Streak",
                                 textColor: textDark, labelColor: textMid,
                                 valueSize: isTall ? 22 : 18)
                        Spacer()
                        StatItem(value: data.avgPerSession.cardFormatted, label: "Avg \(data.primaryUnit)",
                                 textColor: textDark, labelColor: textMid,
                                 valueSize: isTall ? 22 : 18)
                        Spacer()
                    }
                    .padding(.top, 16)
                    if isTall {
                        Text("MyMileage — Every Mile Counts")
                            .font(.pretendard(.medium, size: 10))
                            .foregroundColor(Color(hex: "#cccccc"))
                            .tracking(1)
                            .padding(.top, 12)
                    }
                }
            }
            .padding(isTall ? 32 : 28)
        }
    }
}

// MARK: - C · Streak Amber

private struct CardStreakAmber: View {
    let data: ShareCardData
    let format: ShareCardFormat

    private var isStory: Bool    { format == .story }
    private var isPortrait: Bool { format == .portrait }
    private var isTall: Bool     { isStory || isPortrait }
    private let bg = Color(hex: "#0a0a0a")
    private let amber = Color(hex: "#F5A623")

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Top
                HStack {
                    Text("MyMileage")
                        .font(.pretendard(.semiBold, size: 10))
                        .foregroundColor(Color(hex: "#444444"))
                        .tracking(1.5)
                    Spacer()
                    Text("🔥").font(.system(size: 20))
                }

                Spacer()

                // Streak hero
                VStack(spacing: isTall ? 8 : 4) {
                    Text("CURRENT STREAK")
                        .font(.pretendard(.medium, size: 11))
                        .foregroundColor(Color(hex: "#555555"))
                        .tracking(2)
                    Text("\(data.streak)")
                        .font(.pretendard(.extraBold, size: isTall ? 110 : 88))
                        .foregroundColor(amber)
                        .tracking(-6)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("DAYS")
                        .font(.pretendard(.medium, size: 18))
                        .foregroundColor(Color(hex: "#555555"))
                        .tracking(2)
                }

                if isTall {
                    Spacer().frame(height: 8)
                    Rectangle()
                        .fill(Color(hex: "#1e1e1e"))
                        .frame(height: 1)
                    Spacer().frame(height: 16)
                    Text("\(data.primaryValue.cardFormatted) \(data.primaryUnit) logged this month")
                        .font(.pretendard(.regular, size: 13))
                        .foregroundColor(Color(hex: "#444444"))
                }

                Spacer()

                Text("MyMileage · Every Mile Counts")
                    .font(.pretendard(.medium, size: 10))
                    .foregroundColor(Color(hex: "#333333"))
                    .tracking(1)
            }
            .padding(isTall ? 32 : 28)
        }
    }
}

// MARK: - D · Neon Gradient

private struct CardNeonGradient: View {
    let data: ShareCardData
    let format: ShareCardFormat

    private var isStory: Bool    { format == .story }
    private var isPortrait: Bool { format == .portrait }
    private var isTall: Bool     { isStory || isPortrait }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "#12002a"), Color(hex: "#3b0068"), Color(hex: "#8b1fad"), Color(hex: "#d4379e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Glow orbs
            GeometryReader { geo in
                RadialGradient(
                    colors: [Color(hex: "#d4379e").opacity(0.3), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 180
                )
                RadialGradient(
                    colors: [Color(hex: "#8b1fad").opacity(0.4), .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: 120
                )
                .offset(y: geo.size.height * 0.55)
            }

            VStack(spacing: 0) {
                // Top
                HStack {
                    Text("MyMileage")
                        .font(.pretendard(.semiBold, size: 10))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(2)
                    Spacer()
                    Text(data.monthLabel.uppercased())
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(1.5)
                }

                Spacer()

                // Main number
                VStack(spacing: 4) {
                    Text("THIS MONTH")
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(3)
                    Text(data.primaryValue.cardFormatted)
                        .font(.pretendard(.extraBold, size: isTall ? 120 : 96))
                        .foregroundColor(.white)
                        .tracking(-6)
                        .shadow(color: Color(hex: "#d4379e").opacity(0.8), radius: 20, x: 0, y: 0)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(data.primaryUnit.uppercased())
                        .font(.pretendard(.light, size: 20))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(3)
                }

                if isTall {
                    Spacer().frame(height: 16)
                    // Progress bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("Progress to goal")
                                .font(.pretendard(.regular, size: 10))
                                .foregroundColor(.white.opacity(0.35))
                            Spacer()
                            Text("\(Int(data.progressPercent * 100))%")
                                .font(.pretendard(.regular, size: 10))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.1))
                                    .frame(height: 3)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#d4379e"), Color(hex: "#ff79c6")],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: geo.size.width * min(max(data.progressPercent, 0), 1), height: 3)
                                    .shadow(color: Color(hex: "#d4379e").opacity(0.8), radius: 4)
                            }
                        }
                        .frame(height: 3)
                    }
                }

                Spacer()

                // Stats
                HStack {
                    StatItem(value: "\(data.sessionCount)", label: "Runs",
                             textColor: .white, labelColor: .white.opacity(0.3),
                             valueSize: isTall ? 22 : 18)
                    Spacer()
                    StatItem(value: data.avgPerSession.cardFormatted, label: "Avg",
                             textColor: .white, labelColor: .white.opacity(0.3),
                             valueSize: isTall ? 22 : 18)
                    Spacer()
                    StatItem(value: "\(data.streak)", label: "Streak",
                             textColor: .white, labelColor: .white.opacity(0.3),
                             valueSize: isTall ? 22 : 18)
                }
            }
            .padding(isTall ? 30 : 26)
        }
    }
}

// MARK: - H · Retro Sunrise

private struct CardRetroSunrise: View {
    let data: ShareCardData
    let format: ShareCardFormat

    private var isStory: Bool    { format == .story }
    private var isPortrait: Bool { format == .portrait }
    private var isTall: Bool     { isStory || isPortrait }

    var body: some View {
        ZStack {
            // Sunrise gradient
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#0a0018"), location: 0),
                    .init(color: Color(hex: "#1a0040"), location: 0.20),
                    .init(color: Color(hex: "#6b1060"), location: 0.45),
                    .init(color: Color(hex: "#d4404a"), location: 0.65),
                    .init(color: Color(hex: "#ff8c42"), location: 0.80),
                    .init(color: Color(hex: "#ffd166"), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Grid lines overlay
            GridLinesOverlay()

            // Horizon line
            if isTall {
                GeometryReader { geo in
                    Rectangle()
                        .fill(.white.opacity(0.15))
                        .frame(height: 1)
                        .offset(y: geo.size.height - 100)
                }
            }

            VStack(spacing: 0) {
                // Top
                HStack {
                    Text("MyMileage")
                        .font(.pretendard(.semiBold, size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(2.5)
                    Spacer()
                    Text(data.monthLabel.uppercased())
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(1.5)
                }

                Spacer()

                // Main
                VStack(spacing: 6) {
                    Text("MONTHLY RUN")
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(Color(hex: "#ffd166").opacity(0.7))
                        .tracking(3)
                    Text(data.primaryValue.cardFormatted)
                        .font(.pretendard(.extraBold, size: isTall ? 110 : 88))
                        .foregroundColor(.white)
                        .tracking(-6)
                        .shadow(color: Color(hex: "#ff8c42").opacity(0.6), radius: 15, x: 0, y: 2)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(data.primaryUnit.uppercased())
                        .font(.pretendard(.light, size: isTall ? 18 : 14))
                        .foregroundColor(Color(hex: "#ffd166").opacity(0.7))
                        .tracking(4)
                }

                Spacer()

                // Bottom stats bar
                HStack {
                    Spacer()
                    StatItem(value: "\(data.sessionCount)", label: "Runs",
                             textColor: .white, labelColor: .white.opacity(0.4),
                             valueSize: isTall ? 20 : 16)
                    Spacer()
                    StatItem(value: data.avgPerSession.cardFormatted, label: "Avg \(data.primaryUnit)",
                             textColor: .white, labelColor: .white.opacity(0.4),
                             valueSize: isTall ? 20 : 16)
                    Spacer()
                    StatItem(value: "\(data.streak)", label: "Streak",
                             textColor: .white, labelColor: .white.opacity(0.4),
                             valueSize: isTall ? 20 : 16)
                    Spacer()
                }
                .padding(.vertical, isTall ? 16 : 12)
                .background(.black.opacity(0.25))
                .padding(.horizontal, isTall ? -32 : -26)
                .padding(.bottom, isTall ? -32 : -26)
            }
            .padding(isTall ? 32 : 26)
        }
    }
}

private struct GridLinesOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 30
            var x: CGFloat = 0
            while x <= size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: .color(.white.opacity(0.03)), lineWidth: 1)
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(.white.opacity(0.03)), lineWidth: 1)
                y += step
            }
        }
    }
}

// MARK: - I · Sport Red

private struct CardSportRed: View {
    let data: ShareCardData
    let format: ShareCardFormat

    private var isStory: Bool    { format == .story }
    private var isPortrait: Bool { format == .portrait }
    private var isTall: Bool     { isStory || isPortrait }
    private let red = Color(hex: "#e31e24")

    var body: some View {
        ZStack {
            red.ignoresSafeArea()

            // Circle ring decorations
            GeometryReader { geo in
                Circle()
                    .stroke(.white.opacity(0.07), lineWidth: 40)
                    .frame(width: 260, height: 260)
                    .offset(x: geo.size.width - 130, y: -40)
                Circle()
                    .stroke(.white.opacity(0.05), lineWidth: 30)
                    .frame(width: 160, height: 160)
                    .offset(x: geo.size.width - 80, y: 60)
            }

            VStack(spacing: 0) {
                // Top
                HStack {
                    Text("MyMileage")
                        .font(.pretendard(.semiBold, size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(2.5)
                    Spacer()
                    Text(data.monthLabel.uppercased())
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1)
                }

                Spacer()

                // Main
                VStack(alignment: .leading, spacing: 4) {
                    Text("THIS MONTH")
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(3)
                    Text(data.primaryValue.cardFormatted)
                        .font(.pretendard(.extraBold, size: isTall ? 104 : 84))
                        .foregroundColor(.white)
                        .tracking(-5)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(data.primaryUnit.uppercased())
                        .font(.pretendard(.light, size: isTall ? 24 : 18))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2)

                    Spacer().frame(height: isTall ? 20 : 12)

                    ProgressBar(percent: data.progressPercent,
                                fillColor: .white,
                                trackColor: .white.opacity(0.2),
                                height: 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Stats
                HStack {
                    StatItem(value: "\(data.sessionCount)", label: "Runs",
                             textColor: .white, labelColor: .white.opacity(0.45),
                             valueSize: isTall ? 22 : 18)
                    Spacer()
                    StatItem(value: data.avgPerSession.cardFormatted, label: "Avg \(data.primaryUnit)",
                             textColor: .white, labelColor: .white.opacity(0.45),
                             valueSize: isTall ? 22 : 18)
                    Spacer()
                    StatItem(value: "\(data.streak)", label: "Streak",
                             textColor: .white, labelColor: .white.opacity(0.45),
                             valueSize: isTall ? 22 : 18)
                }
            }
            .padding(isTall ? 28 : 24)
        }
    }
}

// MARK: - 7 · Minimal White

private struct CardMinimalWhite: View {
    let data: ShareCardData
    let format: ShareCardFormat

    private var isStory: Bool    { format == .story }
    private var isPortrait: Bool { format == .portrait }
    private var isTall: Bool     { isStory || isPortrait }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(data.monthLabel.uppercased())
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(Color(hex: "#999999"))
                        .tracking(2)
                    Spacer()
                    Text("MyMileage")
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(Color(hex: "#cccccc"))
                        .tracking(1.5)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 0) {
                    Text(data.primaryValue.cardFormatted)
                        .font(.pretendard(.extraBold, size: isTall ? 100 : 80))
                        .foregroundColor(Color(hex: "#0a0a0a"))
                        .tracking(-5)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(data.primaryUnit)
                        .font(.pretendard(.light, size: isTall ? 28 : 22))
                        .foregroundColor(Color(hex: "#aaaaaa"))
                        .tracking(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isTall {
                    Spacer().frame(height: 20)
                    Rectangle()
                        .fill(Color(hex: "#eeeeee"))
                        .frame(height: 1)
                    Spacer().frame(height: 16)
                }

                Spacer()

                HStack {
                    StatItem(value: "\(data.sessionCount)", label: "Runs",
                             textColor: Color(hex: "#0a0a0a"), labelColor: Color(hex: "#aaaaaa"))
                    Spacer()
                    StatItem(value: data.avgPerSession.cardFormatted, label: "Avg",
                             textColor: Color(hex: "#0a0a0a"), labelColor: Color(hex: "#aaaaaa"))
                    Spacer()
                    StatItem(value: "\(data.streak)", label: "Streak",
                             textColor: Color(hex: "#0a0a0a"), labelColor: Color(hex: "#aaaaaa"))
                }
            }
            .padding(isTall ? 32 : 28)
        }
    }
}

// MARK: - 8 · Mono

private struct CardMono: View {
    let data: ShareCardData
    let format: ShareCardFormat

    private var isStory: Bool    { format == .story }
    private var isPortrait: Bool { format == .portrait }
    private var isTall: Bool     { isStory || isPortrait }

    var body: some View {
        ZStack {
            Color(hex: "#080808").ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("MyMileage")
                        .font(.pretendard(.bold, size: 9))
                        .foregroundColor(Color(hex: "#2a2a2a"))
                        .tracking(3)
                    Spacer()
                    Text(data.monthLabel.uppercased())
                        .font(.pretendard(.medium, size: 9))
                        .foregroundColor(Color(hex: "#2a2a2a"))
                        .tracking(2)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("THIS MONTH")
                        .font(.pretendard(.medium, size: 9))
                        .foregroundColor(Color(hex: "#3a3a3a"))
                        .tracking(3)
                    Text(data.primaryValue.cardFormatted)
                        .font(.pretendard(.extraBold, size: isTall ? 104 : 84))
                        .foregroundColor(.white)
                        .tracking(-5)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(data.primaryUnit.uppercased())
                        .font(.pretendard(.regular, size: isTall ? 18 : 14))
                        .foregroundColor(Color(hex: "#444444"))
                        .tracking(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Stats row
                HStack(spacing: 0) {
                    monoStat(value: String(data.sessionCount), label: "RUNS", isTall: isTall)
                    monoStat(value: data.avgPerSession.cardFormattedShort, label: "AVG", isTall: isTall)
                    monoStat(value: String(data.streak), label: "STREAK", isTall: isTall)
                }
                .padding(.vertical, 12)
                .overlay(
                    Rectangle()
                        .fill(Color(hex: "#1a1a1a"))
                        .frame(height: 1),
                    alignment: .top
                )
            }
            .padding(isTall ? 32 : 28)
        }
    }

    private func monoStat(value: String, label: String, isTall: Bool) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.pretendard(.bold, size: isTall ? 18 : 15))
                .foregroundColor(.white)
            Text(label)
                .font(.pretendard(.medium, size: 8))
                .foregroundColor(Color(hex: "#3a3a3a"))
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 9 · Aqua

private struct CardAqua: View {
    let data: ShareCardData
    let format: ShareCardFormat

    private var isStory: Bool    { format == .story }
    private var isPortrait: Bool { format == .portrait }
    private var isTall: Bool     { isStory || isPortrait }

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#060f14"), location: 0),
                    .init(color: Color(hex: "#0D3B4E"), location: 0.4),
                    .init(color: Color(hex: "#0077a8"), location: 0.75),
                    .init(color: Color(hex: "#00B4D8"), location: 1.0)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Glow orb
            RadialGradient(
                colors: [Color(hex: "#00B4D8").opacity(0.35), .clear],
                center: .bottomTrailing,
                startRadius: 0, endRadius: 220
            )

            VStack(spacing: 0) {
                HStack {
                    Text("MyMileage")
                        .font(.pretendard(.semiBold, size: 10))
                        .foregroundColor(.white.opacity(0.3))
                        .tracking(2)
                    Spacer()
                    Text(data.monthLabel.uppercased())
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(.white.opacity(0.3))
                        .tracking(1.5)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text("THIS MONTH")
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(Color(hex: "#00B4D8").opacity(0.7))
                        .tracking(3)
                    Text(data.primaryValue.cardFormatted)
                        .font(.pretendard(.extraBold, size: isTall ? 110 : 88))
                        .foregroundColor(.white)
                        .tracking(-5)
                        .shadow(color: Color(hex: "#00B4D8").opacity(0.7), radius: 18)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(data.primaryUnit.uppercased())
                        .font(.pretendard(.light, size: isTall ? 20 : 16))
                        .foregroundColor(Color(hex: "#00B4D8").opacity(0.6))
                        .tracking(3)
                }

                if isTall {
                    Spacer().frame(height: 16)
                    ProgressBar(percent: data.progressPercent,
                                fillColor: Color(hex: "#00B4D8"),
                                trackColor: .white.opacity(0.1),
                                height: 3)
                }

                Spacer()

                HStack {
                    StatItem(value: "\(data.sessionCount)", label: "Runs",
                             textColor: .white, labelColor: .white.opacity(0.3), valueSize: isTall ? 22 : 18)
                    Spacer()
                    StatItem(value: data.avgPerSession.cardFormatted, label: "Avg \(data.primaryUnit)",
                             textColor: .white, labelColor: .white.opacity(0.3), valueSize: isTall ? 22 : 18)
                    Spacer()
                    StatItem(value: "\(data.streak)", label: "Streak",
                             textColor: .white, labelColor: .white.opacity(0.3), valueSize: isTall ? 22 : 18)
                }
            }
            .padding(isTall ? 30 : 26)
        }
    }
}

// MARK: - 10 · Ember

private struct CardEmber: View {
    let data: ShareCardData
    let format: ShareCardFormat

    private var isStory: Bool    { format == .story }
    private var isPortrait: Bool { format == .portrait }
    private var isTall: Bool     { isStory || isPortrait }
    private let ember = Color(hex: "#FF4500")

    var body: some View {
        ZStack {
            Color(hex: "#0E0500").ignoresSafeArea()

            // Ember glow
            RadialGradient(
                colors: [ember.opacity(0.28), Color(hex: "#FF4500").opacity(0.08), .clear],
                center: .center,
                startRadius: 0, endRadius: 200
            )

            VStack(spacing: 0) {
                HStack {
                    Text("MyMileage")
                        .font(.pretendard(.semiBold, size: 10))
                        .foregroundColor(Color(hex: "#2a1500"))
                        .tracking(2)
                    Spacer()
                    Text(data.monthLabel.uppercased())
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(Color(hex: "#2a1500"))
                        .tracking(1.5)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text("MONTHLY RUN")
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(ember.opacity(0.6))
                        .tracking(3)
                    Text(data.primaryValue.cardFormatted)
                        .font(.pretendard(.extraBold, size: isTall ? 108 : 86))
                        .foregroundColor(.white)
                        .tracking(-5)
                        .shadow(color: ember.opacity(0.6), radius: 20)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(data.primaryUnit.uppercased())
                        .font(.pretendard(.light, size: isTall ? 20 : 16))
                        .foregroundColor(ember.opacity(0.5))
                        .tracking(3)
                }

                if isTall {
                    Spacer().frame(height: 12)
                    ProgressBar(percent: data.progressPercent,
                                fillColor: ember,
                                trackColor: ember.opacity(0.1),
                                height: 3)
                }

                Spacer()

                HStack {
                    StatItem(value: "\(data.sessionCount)", label: "Runs",
                             textColor: .white, labelColor: ember.opacity(0.4), valueSize: isTall ? 22 : 18)
                    Spacer()
                    StatItem(value: data.avgPerSession.cardFormatted, label: "Avg \(data.primaryUnit)",
                             textColor: .white, labelColor: ember.opacity(0.4), valueSize: isTall ? 22 : 18)
                    Spacer()
                    StatItem(value: "\(data.streak)", label: "Streak",
                             textColor: .white, labelColor: ember.opacity(0.4), valueSize: isTall ? 22 : 18)
                }
            }
            .padding(isTall ? 30 : 26)
        }
    }
}

// MARK: - 11 · Mint

private struct CardMint: View {
    let data: ShareCardData
    let format: ShareCardFormat

    private var isStory: Bool    { format == .story }
    private var isPortrait: Bool { format == .portrait }
    private var isTall: Bool     { isStory || isPortrait }
    private let mint    = Color(hex: "#2D8C5B")
    private let mintBg  = Color(hex: "#F0FFF6")
    private let mintMid = Color(hex: "#C6F6D5")
    private let textDk  = Color(hex: "#0a1f0a")

    var body: some View {
        ZStack {
            mintBg.ignoresSafeArea()

            // Soft radial tint
            RadialGradient(
                colors: [mintMid.opacity(0.5), mintBg],
                center: .bottomLeading,
                startRadius: 0, endRadius: 260
            )

            VStack(spacing: 0) {
                HStack {
                    Text(data.monthLabel.uppercased())
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(mint.opacity(0.5))
                        .tracking(2)
                    Spacer()
                    Text("MyMileage")
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(mint.opacity(0.35))
                        .tracking(1.5)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    if data.isGoalAchieved {
                        Text("Goal Reached")
                            .font(.pretendard(.bold, size: 9))
                            .foregroundColor(.white)
                            .tracking(1.5)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(mint)
                            .clipShape(Capsule())
                            .padding(.bottom, 8)
                    }
                    Text(data.primaryValue.cardFormatted)
                        .font(.pretendard(.extraBold, size: isTall ? 96 : 78))
                        .foregroundColor(textDk)
                        .tracking(-5)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("\(data.primaryUnit) · \(data.monthLabel)")
                        .font(.pretendard(.regular, size: isTall ? 16 : 13))
                        .foregroundColor(mint.opacity(0.6))
                        .tracking(0.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Stats row on card strip
                HStack {
                    StatItem(value: "\(data.sessionCount)", label: "Runs",
                             textColor: textDk, labelColor: mint.opacity(0.5), valueSize: isTall ? 20 : 17)
                    Spacer()
                    StatItem(value: data.avgPerSession.cardFormatted, label: "Avg",
                             textColor: textDk, labelColor: mint.opacity(0.5), valueSize: isTall ? 20 : 17)
                    Spacer()
                    StatItem(value: "\(data.streak)", label: "Streak",
                             textColor: textDk, labelColor: mint.opacity(0.5), valueSize: isTall ? 20 : 17)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(mintMid.opacity(0.6))
                )
            }
            .padding(isTall ? 32 : 28)
        }
    }
}

// MARK: - 12 · Split

private struct CardSplit: View {
    let data: ShareCardData
    let format: ShareCardFormat

    private var isStory: Bool    { format == .story }
    private var isPortrait: Bool { format == .portrait }
    private var isTall: Bool     { isStory || isPortrait }
    private let dark = Color(hex: "#0B0D12")

    var body: some View {
        ZStack {
            dark.ignoresSafeArea()

            HStack(spacing: 0) {
                // Left — accent block
                ZStack {
                    data.accentColor
                    VStack(spacing: 4) {
                        Text(data.primaryValue.cardFormatted)
                            .font(.pretendard(.extraBold, size: isTall ? 64 : 52))
                            .foregroundColor(.black)
                            .tracking(-3)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                        Text(data.primaryUnit.uppercased())
                            .font(.pretendard(.bold, size: isTall ? 13 : 11))
                            .foregroundColor(.black.opacity(0.6))
                            .tracking(2)
                        if isTall {
                            Spacer().frame(height: 4)
                            Text(data.monthLabel.uppercased())
                                .font(.pretendard(.medium, size: 9))
                                .foregroundColor(.black.opacity(0.5))
                                .tracking(1.5)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity)

                // Right — dark stats
                VStack(alignment: .leading, spacing: 0) {
                    Text("MyMileage")
                        .font(.pretendard(.semiBold, size: 9))
                        .foregroundColor(Color(hex: "#3a3a3a"))
                        .tracking(2)

                    Spacer()

                    VStack(alignment: .leading, spacing: isTall ? 16 : 12) {
                        splitStat(value: "\(data.sessionCount)", label: "Runs")
                        splitStat(value: data.avgPerSession.cardFormatted, label: "Avg \(data.primaryUnit)")
                        splitStat(value: "\(data.streak)", label: "Day streak")
                        if isTall {
                            splitStat(value: "\(Int(data.progressPercent * 100))%", label: "Goal")
                        }
                    }

                    Spacer()

                    ProgressBar(percent: data.progressPercent,
                                fillColor: data.accentColor,
                                trackColor: Color(hex: "#1e1e1e"),
                                height: 3)
                }
                .padding(isTall ? 20 : 16)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func splitStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.pretendard(.bold, size: 20))
                .foregroundColor(.white)
            Text(label.uppercased())
                .font(.pretendard(.medium, size: 8))
                .foregroundColor(Color(hex: "#444444"))
                .tracking(1.5)
        }
    }
}
