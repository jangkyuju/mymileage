//
//  Models.swift
//  MotivationRun
//
//  ⚠️ 메인 앱 타겟 + 위젯 타겟 양쪽 Target Membership 체크 필수

import Foundation
import SwiftUI

// MARK: - Color Hex Extension (shared: main app + widget targets)

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6 else { self.init(.clear); return }
        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { self.init(.clear); return }
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - 날짜 유틸 (shared: main app + widget targets)

/// 주어진 기준일을 포함하여 이번 달 남은 일수 반환 (오늘 포함, 최소 1)
func remainingDaysInMonth(from date: Date, calendar: Calendar = .current) -> Int {
    let startOfDay = calendar.startOfDay(for: date)
    guard let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startOfDay)),
          let startOfNextMonth  = calendar.date(byAdding: .month, value: 1, to: startOfThisMonth) else {
        return 1
    }
    return max(calendar.dateComponents([.day], from: startOfDay, to: startOfNextMonth).day ?? 1, 1)
}

// MARK: - AppLanguage

enum AppLanguage: String, Codable, CaseIterable {
    case english = "en"
    case korean  = "ko"
    case german  = "de"
    case french  = "fr"
    case chinese = "zh"
    case spanish = "es"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .korean:  return "한국어"
        case .german:  return "Deutsch"
        case .french:  return "Français"
        case .chinese: return "中文"
        case .spanish: return "Español"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}

// MARK: - GoalType

enum GoalType: String, Codable, CaseIterable {
    case distance  // "km" or "mi"
    case calories  // "kcal"
    case duration  // "hr"

    /// 내부 저장 단위 (표시 레이어에서 변환)
    var unit: String {
        switch self {
        case .distance: return "km"
        case .calories: return "kcal"
        case .duration: return "hr"
        }
    }

    func localizedDisplayName(lang: AppLanguage) -> String {
        switch self {
        case .distance: return L(.goalTypeDistance, lang)
        case .calories: return L(.goalTypeCalories, lang)
        case .duration: return L(.goalTypeDuration, lang)
        }
    }

    /// 표시 단위 (거리는 distanceUnit에 따라 km 또는 mi, 시간은 언어별)
    func displayUnit(distanceUnit: DistanceUnit, lang: AppLanguage = .english) -> String {
        switch self {
        case .distance: return distanceUnit.symbol
        case .calories: return "kcal"
        case .duration: return L(.durationUnit, lang)
        }
    }

    /// 기본 목표값: distance=100km / calories=10000kcal / duration=10시간(hour)
    var defaultTarget: Double {
        switch self {
        case .distance: return 100
        case .calories: return 10000
        case .duration: return 10
        }
    }
}

// MARK: - RunFrequency

enum RunFrequency: Int, Codable, CaseIterable {
    case daily      = 1
    case everyOther = 2
    case every3Days = 3

    func localizedLabel(lang: AppLanguage) -> String {
        switch self {
        case .daily:      return L(.freqDailyLabel, lang)
        case .everyOther: return L(.freqEveryOtherLabel, lang)
        case .every3Days: return L(.freqEvery3DaysLabel, lang)
        }
    }

    /// "매일 러닝 시" / "Daily run" 형태 (카드 우측 & 위젯에 사용)
    func localizedRunLabel(lang: AppLanguage) -> String {
        switch self {
        case .daily:      return L(.freqDailyRun, lang)
        case .everyOther: return L(.freqEveryOtherRun, lang)
        case .every3Days: return L(.freqEvery3DaysRun, lang)
        }
    }

    /// 남은 일수를 기준으로 예상 러닝 횟수 반환 (최소 1.0)
    func expectedSessions(remainingDays: Int) -> Double {
        max(Double(remainingDays) / Double(rawValue), 1.0)
    }
}

// MARK: - DistanceUnit

enum DistanceUnit: String, Codable, CaseIterable {
    case km, mile

    func localizedLabel(lang: AppLanguage) -> String {
        self == .km ? L(.unitKilometer, lang) : L(.unitMile, lang)
    }

    var symbol: String {
        switch self {
        case .km:   return "km"
        case .mile: return "mi"
        }
    }

    /// 킬로미터 → 선택 단위 변환 계수
    var conversionFromKm: Double {
        self == .mile ? 0.621371 : 1.0
    }
}

// MARK: - ThemeAccent

enum ThemeAccent: String, Codable, CaseIterable {
    case blue, green, orange, red, purple, yellow

    var label: String {
        switch self {
        case .blue:   return "Blue"
        case .green:  return "Green"
        case .orange: return "Orange"
        case .red:    return "Red"
        case .purple: return "Purple"
        case .yellow: return "Yellow"
        }
    }

    // HMG Point Color System — base color for light theme
    var color: Color {
        switch self {
        case .blue:   return Color(hex: "#3478FE")
        case .green:  return Color(hex: "#04B249")
        case .orange: return Color(hex: "#FD6A00")
        case .red:    return Color(hex: "#F13E3E")
        case .purple: return Color(hex: "#913DE5")
        case .yellow: return Color(hex: "#FFB902")
        }
    }

    // Dark theme variant (brighter for contrast on dark bg)
    var colorDark: Color {
        switch self {
        case .blue:   return Color(hex: "#94BBFF")
        case .green:  return Color(hex: "#38B249")
        case .orange: return Color(hex: "#FD8C2F")
        case .red:    return Color(hex: "#F75050")
        case .purple: return Color(hex: "#B266EE")
        case .yellow: return Color(hex: "#F9BA21")
        }
    }

    // Soft container background
    var containerColor: Color {
        switch self {
        case .blue:   return Color(hex: "#ECF6FF")
        case .green:  return Color(hex: "#EBF4EE")
        case .orange: return Color(hex: "#FFEBDD")
        case .red:    return Color(hex: "#FEECEC")
        case .purple: return Color(hex: "#F5EBFE")
        case .yellow: return Color(hex: "#FCF2D8")
        }
    }

    /// 포인트 색상 위에 올라가는 텍스트/아이콘 색상
    var foregroundColor: Color {
        switch self {
        case .yellow, .orange: return Color(hex: "#0E1116")
        case .blue, .green, .red, .purple: return .white
        }
    }
}

// MARK: - ThemeBackground

enum ThemeBackground: String, Codable, CaseIterable {
    case black, white

    func localizedLabel(lang: AppLanguage) -> String {
        self == .black ? L(.themeDark, lang) : L(.themeLight, lang)
    }

    var isDark: Bool  { self == .black }
    var colorScheme: ColorScheme { isDark ? .dark : .light }

    // HMG Design System Tokens
    // Light: #F4F5F7 bg, #FFFFFF card, Hyundai Navy #0A1F4A primary
    // Dark: #0B0D12 bg, #161A22 card, Blue #5790FE primary

    var appBg:    Color {
        isDark ? Color(hex: "#0B0D12") : Color(hex: "#E8EAED")
    }
    var cardBg:   Color {
        isDark ? Color(hex: "#161A22") : Color(hex: "#F5F6F8")
    }
    var cardSoft: Color {
        isDark ? Color(hex: "#1B2029") : Color(hex: "#F0F1F4")
    }
    var grayBg:   Color {
        isDark ? Color(hex: "#262B36") : Color(hex: "#DFE1E5")
    }
    var graySoft: Color {
        isDark ? Color(hex: "#1E2330") : Color(hex: "#E6E8EB")
    }
    var subText:  Color {
        isDark ? Color(hex: "#6B768C") : Color(hex: "#8E949F")
    }
    var mainText: Color {
        isDark ? Color(hex: "#F2F3F5") : Color(hex: "#0E1116")
    }
    var lineColor: Color {
        isDark ? Color(hex: "#262B36") : Color(hex: "#ECEEF1")
    }
    // Medium-grey text (between mainText and subText)
    var inkMid: Color {
        isDark ? Color(hex: "#9FA6B2") : Color(hex: "#5C6779")
    }
    // Lightest grey text / disabled / placeholder
    var inkOff: Color {
        isDark ? Color(hex: "#4A5366") : Color(hex: "#B2B6BD")
    }
}

// MARK: - WidgetDesign

enum WidgetDesign: String, Codable, CaseIterable {
    case minimal, compact, balanced, complete

    func localizedLabel(lang: AppLanguage) -> String {
        switch self {
        case .minimal:  return L(.widgetDesignMinimal, lang)
        case .compact:  return L(.widgetDesignCompact, lang)
        case .balanced: return L(.widgetDesignBalanced, lang)
        case .complete: return L(.widgetDesignComplete, lang)
        }
    }
}

// MARK: - NotificationSettings

struct NotificationSettings: Codable {
    var isEnabled: Bool = true    // 매일 습관 알림 on/off (단일 마스터, 기본 ON)
    var reminderHour: Int = 19    // 알림 시각 - 시 (기본 19시)
    var reminderMinute: Int = 0   // 알림 시각 - 분 (기본 0분)
}

// MARK: - RunSession

struct RunSession: Codable, Identifiable {
    var id: UUID
    var hkWorkoutID: UUID?          // ← 추가 (구 데이터: nil로 디코딩)
    var date: Date
    var distanceKm: Double
    var calories: Double
    var durationMinutes: Double

    var paceMinPerKm: Double {
        guard distanceKm > 0 else { return 0 }
        return durationMinutes / distanceKm
    }

    var paceString: String {
        let totalSeconds = Int(paceMinPerKm * 60)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes)'\(String(format: "%02d", seconds))\""
    }
}

// MARK: - MonthlyStats

struct MonthlyStats: Codable {
    var year: Int
    var month: Int
    var totalDistanceKm: Double
    var totalCalories: Double
    var totalDurationMinutes: Double
    var goalType: GoalType
    var goalTarget: Double
    var lastSyncTime: Date
    var activitiesCount: Int
    var sessions: [RunSession]
    var totalSteps: Int?
    var avgHeartRateBpm: Double?

    /// goalType에 따른 현재 달성값 (거리는 km 기준 — 표시 레이어에서 단위 변환)
    var currentValue: Double {
        switch goalType {
        case .distance: return totalDistanceKm
        case .calories: return totalCalories
        case .duration: return totalDurationMinutes / 60
        }
    }

    /// distanceUnit을 적용한 표시용 달성값 (streak/알림 비교에 사용)
    func displayCurrentValue(distanceUnit: DistanceUnit) -> Double {
        switch goalType {
        case .distance: return totalDistanceKm * distanceUnit.conversionFromKm
        case .calories: return totalCalories
        case .duration: return totalDurationMinutes / 60
        }
    }
}

// MARK: - RunJournalEntry

struct RunJournalEntry: Codable {
    var difficulty: Double   // 0.0 – 1.0
    var diary: String
    var updatedAt: Date
}

// MARK: - WorkoutSourcePreference

struct WorkoutSourcePreference: Codable {
    var allowedBundleIDs: [String] = []
    var isConfigured: Bool = false

    func allows(bundleID: String) -> Bool {
        guard isConfigured && !allowedBundleIDs.isEmpty else { return true }
        return allowedBundleIDs.contains(bundleID)
    }
}
