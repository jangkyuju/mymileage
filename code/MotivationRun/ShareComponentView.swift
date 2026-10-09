//
//  ShareComponentView.swift
//  MotivationRun
//
//  5 exportable stat component views: NumberTile, MonthlyBarChart,
//  CumulativeLine, StreakBadge, StatsTrio
//

import SwiftUI

// MARK: - Component type

enum ShareComponent: String, CaseIterable, Identifiable {
    case numberTile
    case monthlyBar
    case cumulativeLine
    case streakBadge
    case statsTrio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .numberTile:     return "Number Tile"
        case .monthlyBar:     return "Monthly Bar"
        case .cumulativeLine: return "Cumulative Line"
        case .streakBadge:    return "Streak Badge"
        case .statsTrio:      return "Stats Trio"
        }
    }

    var icon: String {
        switch self {
        case .numberTile:     return "number.square.fill"
        case .monthlyBar:     return "chart.bar.fill"
        case .cumulativeLine: return "chart.line.uptrend.xyaxis"
        case .streakBadge:    return "flame.fill"
        case .statsTrio:      return "square.grid.3x1.fill.below.line.grid.1x2"
        }
    }

    var isPro: Bool {
        switch self {
        case .monthlyBar, .cumulativeLine: return true
        default: return false
        }
    }

    var description: String {
        switch self {
        case .numberTile:     return "Big monthly stat, transparent background"
        case .monthlyBar:     return "Daily bar chart for the month"
        case .cumulativeLine: return "Cumulative progress line graph"
        case .streakBadge:    return "Current running streak badge"
        case .statsTrio:      return "Runs · Average · Streak row"
        }
    }

    // Fixed render sizes (points — rendered @3x for export)
    var renderSize: CGSize {
        switch self {
        case .numberTile:     return CGSize(width: 360, height: 200)
        case .monthlyBar:     return CGSize(width: 360, height: 280)
        case .cumulativeLine: return CGSize(width: 360, height: 280)
        case .streakBadge:    return CGSize(width: 240, height: 240)
        case .statsTrio:      return CGSize(width: 360, height: 160)
        }
    }
}

// MARK: - Number Tile

struct NumberTileComponent: View {
    let data: ShareCardData

    var body: some View {
        ZStack {
            Color.black
            VStack(alignment: .leading, spacing: 4) {
                Text(data.monthLabel.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(formattedValue)
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(data.primaryUnit)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(data.accentColor)
                }
                Text("\(data.sessionCount) runs  ·  \(Int(data.progressPercent * 100))% of goal")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 360, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var formattedValue: String {
        switch data.goalType {
        case .distance, .calories: return "\(Int(data.primaryValue.rounded()))"
        case .duration:
            if data.primaryValue.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(data.primaryValue))"
            }
            return String(format: "%.1f", data.primaryValue)
        }
    }
}

// MARK: - Monthly Bar Chart

struct MonthlyBarChartComponent: View {
    let data: ShareCardData

    var body: some View {
        ZStack {
            Color(hex: "#111111")
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MONTHLY ACTIVITY")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(2)
                    Text(data.monthLabel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                GeometryReader { geo in
                    barChart(in: geo)
                }
                HStack {
                    Text("\(data.primaryUnit)/day")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                    Text("Total: \(formattedTotal) \(data.primaryUnit)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(data.accentColor)
                }
            }
            .padding(24)
        }
        .frame(width: 360, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func barChart(in geo: GeometryProxy) -> some View {
        let values = data.dailyValues
        guard !values.isEmpty else { return AnyView(EmptyView()) }
        let maxVal = values.max() ?? 1
        let barW = max((geo.size.width - CGFloat(values.count - 1) * 2) / CGFloat(values.count), 2)
        return AnyView(
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(values.indices, id: \.self) { i in
                    let h = maxVal > 0 ? CGFloat(values[i] / maxVal) * geo.size.height : 0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(values[i] > 0 ? data.accentColor : Color.white.opacity(0.08))
                        .frame(width: barW, height: max(h, values[i] > 0 ? 3 : 1))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        )
    }

    private var formattedTotal: String {
        switch data.goalType {
        case .distance: return String(format: "%.1f", data.primaryValue)
        case .calories: return "\(Int(data.primaryValue))"
        case .duration: return String(format: "%.1f", data.primaryValue)
        }
    }
}

// MARK: - Cumulative Line

struct CumulativeLineComponent: View {
    let data: ShareCardData

    var body: some View {
        ZStack {
            Color(hex: "#0d0d0d")
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CUMULATIVE PROGRESS")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(2)
                    Text(data.monthLabel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                GeometryReader { geo in
                    lineChart(in: geo)
                }
                HStack {
                    Text("Goal: \(goalFormatted) \(data.primaryUnit)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                    Text("\(Int(data.progressPercent * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(data.accentColor)
                }
            }
            .padding(24)
        }
        .frame(width: 360, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var goalFormatted: String {
        switch data.goalType {
        case .distance: return String(format: "%.0f", data.goalTarget)
        case .calories: return "\(Int(data.goalTarget))"
        case .duration: return String(format: "%.1f", data.goalTarget)
        }
    }

    private func lineChart(in geo: GeometryProxy) -> some View {
        let values = data.cumulativeValues
        guard values.count >= 2 else { return AnyView(EmptyView()) }
        let maxVal = max(values.last ?? 1, data.goalTarget, 1)
        let w = geo.size.width
        let h = geo.size.height

        let points: [CGPoint] = values.indices.map { i in
            CGPoint(
                x: w * CGFloat(i) / CGFloat(values.count - 1),
                y: h - h * CGFloat(values[i] / maxVal)
            )
        }

        // Goal line y
        let goalY = h - h * CGFloat(data.goalTarget / maxVal)

        return AnyView(
            ZStack {
                // Goal dashed line
                Path { p in
                    p.move(to: CGPoint(x: 0, y: goalY))
                    p.addLine(to: CGPoint(x: w, y: goalY))
                }
                .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // Filled area
                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: CGPoint(x: first.x, y: h))
                    p.addLine(to: first)
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                    if let last = points.last { p.addLine(to: CGPoint(x: last.x, y: h)) }
                    p.closeSubpath()
                }
                .fill(data.accentColor.opacity(0.15))

                // Line stroke
                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(data.accentColor, lineWidth: 2)

                // End dot
                if let last = points.last {
                    Circle()
                        .fill(data.accentColor)
                        .frame(width: 8, height: 8)
                        .position(last)
                }
            }
        )
    }
}

// MARK: - Streak Badge

struct StreakBadgeComponent: View {
    let data: ShareCardData

    var body: some View {
        ZStack {
            Color(hex: "#111111")
            VStack(spacing: 8) {
                Text("🔥")
                    .font(.system(size: 48))
                Text("\(data.streak)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("day streak")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(data.accentColor)
                    .tracking(1)
            }
        }
        .frame(width: 240, height: 240)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(data.accentColor.opacity(0.4), lineWidth: 2)
        )
    }
}

// MARK: - Stats Trio

struct StatsTrioComponent: View {
    let data: ShareCardData

    var body: some View {
        ZStack {
            Color(hex: "#111111")
            HStack(spacing: 0) {
                statCell(value: "\(data.sessionCount)", label: "Runs")
                divider
                statCell(value: avgFormatted, label: "Avg/run")
                divider
                statCell(value: "\(data.streak)", label: "Streak")
            }
            .padding(.horizontal, 20)
        }
        .frame(width: 360, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var avgFormatted: String {
        switch data.goalType {
        case .distance, .duration: return String(format: "%.1f", data.avgPerSession)
        case .calories: return "\(Int(data.avgPerSession.rounded()))"
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 60)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(data.accentColor)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Component renderer helper

@MainActor
func renderComponent(_ component: ShareComponent, data: ShareCardData) -> UIImage? {
    let size = component.renderSize
    let view: AnyView
    switch component {
    case .numberTile:
        view = AnyView(NumberTileComponent(data: data))
    case .monthlyBar:
        view = AnyView(MonthlyBarChartComponent(data: data))
    case .cumulativeLine:
        view = AnyView(CumulativeLineComponent(data: data))
    case .streakBadge:
        view = AnyView(StreakBadgeComponent(data: data))
    case .statsTrio:
        view = AnyView(StatsTrioComponent(data: data))
    }
    // Export는 고정 사이즈로 렌더링 — 사용자 Dynamic Type 설정의 영향을 받지 않는다.
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height).environment(\.dynamicTypeSize, .large))
    renderer.scale = 3
    return renderer.uiImage
}
