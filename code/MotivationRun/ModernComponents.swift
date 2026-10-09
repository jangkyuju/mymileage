//
//  ModernComponents.swift
//  MotivationRun — HMG Design System Components
//

import SwiftUI
import UIKit

// MARK: - Pretendard Font Extension

extension Font {
    static func pretendard(_ weight: PretendardWeight, size: CGFloat) -> Font {
        .custom(weight.postScriptName, size: size)
    }
}

enum PretendardWeight {
    case light, regular, medium, semiBold, bold, extraBold

    var postScriptName: String {
        switch self {
        case .light:     return "Pretendard-Light"
        case .regular:   return "Pretendard-Regular"
        case .medium:    return "Pretendard-Medium"
        case .semiBold:  return "Pretendard-SemiBold"
        case .bold:      return "Pretendard-Bold"
        case .extraBold: return "Pretendard-ExtraBold"
        }
    }
}

// MARK: - Floating Tab Bar (HMG Design · Pill Card)

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    let isDark: Bool
    let appBg: Color
    let cardBg: Color
    let primaryColor: Color
    let primarySoft: Color
    let inkLow: Color

    private var safeBottom: CGFloat {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: { $0.isKeyWindow })?
            .safeAreaInsets.bottom ?? 0
    }

    private func selectTab(_ i: Int) {
        guard i != selectedTab else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.15)) { selectedTab = i }
    }

    private let tabs: [(icon: String, label: String)] = [
        ("chart.bar.fill",        "Dashboard"),
        ("list.bullet.rectangle", "Log"),
        ("calendar",              "Calendar"),
        ("gearshape.fill",        "Settings"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Gradient fades content into solid bg — transparent at top, solid at bottom
            LinearGradient(
                colors: [appBg.opacity(0), appBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)
            .allowsHitTesting(false)

            // Pill card on solid background (blocks all content below)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(0..<tabs.count, id: \.self) { i in
                        let on = selectedTab == i
                        VStack(spacing: 3) {
                            Image(systemName: tabs[i].icon)
                                .font(.system(size: 20, weight: on ? .semibold : .regular))
                                .foregroundColor(on ? primaryColor : inkLow)
                            Text(tabs[i].label)
                                .font(AppFont.caption2(on ? .bold : .medium))
                                .foregroundColor(on ? primaryColor : inkLow)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(on ? primarySoft : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .accessibilityLabel(Text(tabs[i].label))
                        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                        .onTapGesture { selectTab(i) }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(cardBg)
                        .shadow(
                            color: isDark ? .black.opacity(0.5) : Color(hex: "#0D1220").opacity(0.08),
                            radius: 12, x: 0, y: 4
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(
                                    isDark ? Color.white.opacity(0.06) : Color(hex: "#0D1220").opacity(0.05),
                                    lineWidth: 1
                                )
                        )
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 1)
            }
            .frame(maxWidth: .infinity)
            .background(appBg)
        }
    }
}

// MARK: - App Type Scale (3번: Dynamic Type 대응)
//
// .custom(name:size:relativeTo:)은 기본 콘텐츠 크기에서 기존 고정 사이즈와
// 동일하게 렌더링되며, 사용자가 큰 텍스트를 켰을 때만 스케일된다.
// 공유카드 Export·위젯에는 사용하지 말 것 (Export 레이아웃 고정 유지).

enum AppFont {
    static func scaled(_ weight: PretendardWeight, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: style)
    }
    static func largeTitle(_ weight: PretendardWeight = .bold) -> Font { scaled(weight, size: 28, relativeTo: .largeTitle) }
    static func title(_ weight: PretendardWeight = .bold) -> Font { scaled(weight, size: 22, relativeTo: .title) }
    static func headline(_ weight: PretendardWeight = .semiBold) -> Font { scaled(weight, size: 17, relativeTo: .headline) }
    static func body(_ weight: PretendardWeight = .regular) -> Font { scaled(weight, size: 15, relativeTo: .body) }
    static func callout(_ weight: PretendardWeight = .regular) -> Font { scaled(weight, size: 13, relativeTo: .callout) }
    static func caption(_ weight: PretendardWeight = .medium) -> Font { scaled(weight, size: 11, relativeTo: .caption) }
    static func caption2(_ weight: PretendardWeight = .medium, size: CGFloat = 10) -> Font { scaled(weight, size: size, relativeTo: .caption2) }
}

// MARK: - App Card (HMG · 16px radius · subtle shadow)

struct AppCard<Content: View>: View {
    let pad: CGFloat
    let isDark: Bool
    let cardBg: Color
    let content: Content

    init(pad: CGFloat = 16, isDark: Bool, cardBg: Color, @ViewBuilder content: () -> Content) {
        self.pad = pad
        self.isDark = isDark
        self.cardBg = cardBg
        self.content = content()
    }

    var body: some View {
        content
            .padding(pad)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBg)
                    .shadow(
                        color: isDark ? .black.opacity(0.3) : Color(hex: "#0D1220").opacity(0.03),
                        radius: 2, x: 0, y: 1
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isDark ? Color.white.opacity(0.05) : Color(hex: "#0D1220").opacity(0.04),
                                lineWidth: 1
                            )
                    )
            )
    }
}

// MARK: - Goal Progress Ring (Dashboard Hero)

struct GoalProgressRing: View {
    let progress: Double   // 0.0 – 1.0
    let isDark: Bool
    // Ring always sits on a dark accent banner → white gradient for universal contrast
    private let size: CGFloat = 132
    private let stroke: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: stroke)

            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)

            VStack(spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text("\(Int(min(progress, 1.0) * 100))")
                        .font(.pretendard(.bold, size: 28))
                        .foregroundColor(.white)
                    Text("%")
                        .font(.pretendard(.bold, size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                Text("of goal")
                    .font(.pretendard(.medium, size: 11))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Legacy Progress Ring (used by widget preview, kept for compat)

struct ProgressRing: View {
    let progress: Double
    let primaryColor: Color
    let size: CGFloat = 140

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "#E9EAEC"), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [primaryColor, primaryColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            VStack(spacing: 4) {
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.pretendard(.bold, size: 32))
                    .foregroundColor(primaryColor)
                Text("of goal")
                    .font(.pretendard(.medium, size: 12))
                    .foregroundColor(Color(hex: "#8E949F"))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Stat Chip (Dashboard Summary 2×3 Grid)

struct StatChip: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let accentColor: Color
    let accentSoft: Color
    let isDark: Bool
    let cardBg: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(accentSoft)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.pretendard(.bold, size: 22))
                        .foregroundColor(isDark ? Color(hex: "#F2F3F5") : Color(hex: "#0E1116"))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.pretendard(.semiBold, size: 11))
                            .foregroundColor(isDark ? Color(hex: "#6B768C") : Color(hex: "#8E949F"))
                    }
                }
                Text(label)
                    .font(.pretendard(.medium, size: 11))
                    .foregroundColor(isDark ? Color(hex: "#6B768C") : Color(hex: "#8E949F"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isDark ? Color.white.opacity(0.05) : Color(hex: "#0D1220").opacity(0.04),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Eyebrow Label

struct EyebrowLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.pretendard(.bold, size: 11))
            .foregroundColor(color)
            .kerning(0.8)
    }
}

// MARK: - Segmented Picker (HMG style)

struct HMGSegmentedPicker: View {
    let options: [String]
    @Binding var selected: Int
    let isDark: Bool
    let cardBg: Color
    let lineSoft: Color
    let inkMid: Color
    let inkColor: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                let on = selected == i
                Button(action: { selected = i }) {
                    Text(options[i])
                        .font(.pretendard(on ? .bold : .medium, size: 12.5))
                        .foregroundColor(on ? inkColor : inkMid)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(on ? cardBg : Color.clear)
                                .shadow(
                                    color: on ? (isDark ? .black.opacity(0.4) : Color(hex: "#0D1220").opacity(0.06)) : .clear,
                                    radius: 1, x: 0, y: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(lineSoft)
        )
    }
}

// MARK: - Toggle Row (Settings)

struct SettingsToggleRow: View {
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool
    let isDark: Bool
    let inkColor: Color
    let lineSoft: Color
    let isLast: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(iconBg)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(.pretendard(.semiBold, size: 14))
                .foregroundColor(inkColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(iconColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(lineSoft)
                    .frame(height: 1)
                    .padding(.leading, 58)
            }
        }
    }
}

// MARK: - Settings Chevron Row

struct SettingsChevronRow: View {
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let title: String
    var value: String = ""
    var isDanger: Bool = false
    let isDark: Bool
    let inkColor: Color
    let inkMid: Color
    let inkOff: Color
    let lineSoft: Color
    let isLast: Bool
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(iconBg)
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.pretendard(.semiBold, size: 14))
                    .foregroundColor(isDanger ? Color(hex: "#F13E3E") : inkColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !value.isEmpty {
                    Text(value)
                        .font(.pretendard(.regular, size: 13))
                        .foregroundColor(inkMid)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(inkOff)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(lineSoft)
                    .frame(height: 1)
                    .padding(.leading, 58)
            }
        }
    }
}

// MARK: - ModernCard (legacy compat)

struct ModernCard<Content: View>: View {
    let content: Content
    let isDark: Bool

    init(isDark: Bool, @ViewBuilder content: () -> Content) {
        self.isDark = isDark
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(isDark ? Color(hex: "#161A22") : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDark ? Color(hex: "#262B36") : Color(hex: "#ECEEF1"), lineWidth: 1)
            )
    }
}

// MARK: - HeatmapCell (legacy compat)

struct HeatmapCell: View {
    let value: Double
    let isDark: Bool
    let primaryColor: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        isDark ? Color(hex: "#1A2640") : primaryColor.opacity(0.1),
                        primaryColor.opacity(Double(value))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isDark ? Color(hex: "#262B36") : Color(hex: "#ECEEF1"), lineWidth: 0.5)
            )
    }
}

// MARK: - ModernStatCard (legacy compat)

struct ModernStatCard: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let accentColor: Color
    let isDark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(accentColor)
                    .cornerRadius(6)
                Spacer()
            }
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.pretendard(.bold, size: 18))
                    .foregroundColor(isDark ? Color(hex: "#F2F3F5") : Color(hex: "#0E1116"))
                if !unit.isEmpty {
                    Text(unit)
                        .font(.pretendard(.medium, size: 11))
                        .foregroundColor(isDark ? Color(hex: "#6B768C") : Color(hex: "#8E949F"))
                }
            }
            Text(label)
                .font(.pretendard(.medium, size: 11))
                .foregroundColor(isDark ? Color(hex: "#6B768C") : Color(hex: "#8E949F"))
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isDark ? Color(hex: "#1B2029") : Color(hex: "#FAFBFD"))
        .cornerRadius(8)
        .frame(minHeight: 100)
    }
}

// MARK: - SegmentedStatContainer (legacy compat)

struct SegmentedStatContainer: View {
    let distance: String
    let duration: String
    let calories: String
    let accentColor: Color
    let isDark: Bool

    var body: some View {
        HStack(spacing: 12) {
            StatPill(icon: "figure.run",  value: distance, label: "Distance", accentColor: accentColor, isDark: isDark)
            StatPill(icon: "clock.fill",  value: duration, label: "Duration",  accentColor: accentColor, isDark: isDark)
            StatPill(icon: "flame.fill",  value: calories, label: "Calories",  accentColor: accentColor, isDark: isDark)
        }
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let accentColor: Color
    let isDark: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)
            Text(value)
                .font(.pretendard(.bold, size: 13))
                .foregroundColor(isDark ? Color(hex: "#F2F3F5") : Color(hex: "#0E1116"))
            Text(label)
                .font(.pretendard(.medium, size: 10))
                .foregroundColor(isDark ? Color(hex: "#6B768C") : Color(hex: "#8E949F"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isDark ? Color(hex: "#1A2640") : accentColor.opacity(0.08))
        .cornerRadius(8)
    }
}
