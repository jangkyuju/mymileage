//
//  ContentView.swift
//  MotivationRun — Dynamic Theme + Multi-language Design
//

import SwiftUI
import UIKit
import StoreKit
import WidgetKit

// MARK: - 차트 지표 탭

enum ChartMetric: CaseIterable {
    case distance, duration, calories

    func label(lang: AppLanguage) -> String {
        switch self {
        case .distance: return L(.dashboardTotalDistance, lang)
        case .duration: return L(.dashboardTotalDuration, lang)
        case .calories: return L(.dashboardTotalCalories, lang)
        }
    }

    func unit(distanceUnit: DistanceUnit) -> String {
        switch self {
        case .distance: return distanceUnit.symbol
        case .duration: return "min"
        case .calories: return "kcal"
        }
    }
}

// MARK: - 공유 헬퍼

private func streakFromSessions(_ sessions: [RunSession]) -> Int {
    let cal = Calendar.current
    var streak = 0
    var checkDate = cal.startOfDay(for: Date())
    let runDays = Set(sessions.map { cal.startOfDay(for: $0.date) })
    while runDays.contains(checkDate) {
        streak += 1
        guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
        checkDate = prev
    }
    return streak
}

// MARK: - 메인 뷰

struct ContentView: View {
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var themeStore = ThemeStore()

    @State private var goalTarget: Double = 100.0
    @State private var goalType: GoalType = .distance
    @State private var runFrequency: RunFrequency = .everyOther
    @State private var lastSync: Date?
    @State private var isSyncing: Bool = false
    @State private var isAuthorized: Bool = false
    @State private var showGoalSheet: Bool = false
    @State private var showHelpSheet: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var themeAccent: ThemeAccent = .blue
    @State private var themeBackground: ThemeBackground = .white
    @State private var distanceUnit: DistanceUnit = .km
    @State private var appLanguage: AppLanguage = .english
    @State private var notificationSettings: NotificationSettings = NotificationSettings()
    @State private var selectedTab: Int = 0
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false
    @State private var showCelebration: Bool = false

    // MARK: - 월 네비게이션
    @State private var allSessions: [RunSession] = []
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var isLoadingSessions: Bool = false
    @State private var chartMetric: ChartMetric = .distance
    @State private var monthlyStats: MonthlyStats?

    // MARK: - 테마 색상 (동적)
    private var cAccent:   Color { themeBackground.isDark ? themeAccent.colorDark : themeAccent.color }
    private var cBg:       Color { themeBackground.appBg }
    private var cCard:     Color { themeBackground.cardBg }
    private var cGray:     Color { themeBackground.grayBg }
    private var cText:     Color { themeBackground.mainText }
    private var cSub:      Color { themeBackground.subText }

    /// 현재 언어로 번역
    private func t(_ key: LK) -> String { L(key, appLanguage) }

    // MARK: - 현재 월 여부
    private var isCurrentMonth: Bool {
        let cal = Calendar.current
        let now = Date()
        return selectedYear == cal.component(.year, from: now) &&
               selectedMonth == cal.component(.month, from: now)
    }

    // MARK: - 선택된 월의 세션
    private var selectedMonthSessions: [RunSession] {
        let cal = Calendar.current
        return allSessions.filter { session in
            let comps = cal.dateComponents([.year, .month], from: session.date)
            return comps.year == selectedYear && comps.month == selectedMonth
        }.sorted { $0.date > $1.date }
    }

    // MARK: - 선택된 월 통계
    private var monthTotalDistanceKm: Double {
        selectedMonthSessions.reduce(0) { $0 + $1.distanceKm }
    }
    private var monthTotalCalories: Double {
        selectedMonthSessions.reduce(0) { $0 + $1.calories }
    }
    private var monthTotalDurationMin: Double {
        selectedMonthSessions.reduce(0) { $0 + $1.durationMinutes }
    }
    private var monthSessionCount: Int { selectedMonthSessions.count }

    private var monthDisplayDistance: Double {
        monthTotalDistanceKm * distanceUnit.conversionFromKm
    }

    private var monthAvgPaceStr: String {
        guard monthTotalDistanceKm > 0 else { return "-" }
        let dist = monthTotalDistanceKm * distanceUnit.conversionFromKm
        let pacePerUnit = monthTotalDurationMin / dist
        let totalSec = Int(pacePerUnit * 60)
        let m = totalSec / 60
        let s = totalSec % 60
        return "\(m)'\(String(format: "%02d", s))\""
    }

    private var monthAvgDistancePerRun: Double {
        guard monthSessionCount > 0 else { return 0 }
        return monthDisplayDistance / Double(monthSessionCount)
    }

    private var monthDurationStr: String {
        let total = Int(monthTotalDurationMin)
        let h = total / 60
        let m = total % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private var monthTotalStepsStr: String {
        guard let steps = monthlyStats?.totalSteps, steps > 0 else { return "-" }
        if steps >= 10_000 { return String(format: "%.1fk", Double(steps) / 1_000) }
        return "\(steps)"
    }

    private var monthAvgHeartRateStr: String {
        guard let hr = monthlyStats?.avgHeartRateBpm, hr > 0 else { return "-" }
        return "\(Int(hr.rounded()))"
    }

    private var remainingDays: Int {
        remainingDaysInMonth(from: Date())
    }

    // MARK: - 선택된 월 표시 문자열
    private var selectedMonthString: String {
        let f = DateFormatter()
        f.locale = appLanguage.locale
        f.dateFormat = t(.monthYearDateFormat)
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = selectedMonth
        comps.day = 1
        guard let date = Calendar.current.date(from: comps) else { return "" }
        return f.string(from: date)
    }

    private var todayDayString: String {
        let f = DateFormatter()
        f.locale = appLanguage.locale
        f.dateFormat = "d MMM"
        return f.string(from: Date())
    }

    private var celebrationPrimaryValue: Double {
        switch goalType {
        case .distance: return monthTotalDistanceKm * distanceUnit.conversionFromKm
        case .calories: return monthTotalCalories
        case .duration: return monthTotalDurationMin / 60
        }
    }

    private var celebrationPrimaryUnit: String {
        switch goalType {
        case .distance: return distanceUnit.symbol
        case .calories: return "kcal"
        case .duration: return "hr"
        }
    }

    private func navigateMonth(delta: Int) {
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = selectedMonth
        comps.day = 1
        guard let current = Calendar.current.date(from: comps),
              let next = Calendar.current.date(byAdding: .month, value: delta, to: current) else { return }
        let cal = Calendar.current
        selectedYear = cal.component(.year, from: next)
        selectedMonth = cal.component(.month, from: next)
    }

    private var canGoForward: Bool {
        let cal = Calendar.current
        let nowY = cal.component(.year, from: Date())
        let nowM = cal.component(.month, from: Date())
        return (selectedYear < nowY) || (selectedYear == nowY && selectedMonth < nowM)
    }

    var body: some View {
        // Tab content — all kept in memory to preserve scroll state.
        // .overlay places FloatingTabBar in a separate UIKit layer above NavigationStack,
        // which avoids UIKit hit-test interception from the UINavigationController.
        ZStack {
            dashboardTab()
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)

            LogView(themeAccent: themeAccent, themeBackground: themeBackground,
                    distanceUnit: distanceUnit, appLanguage: appLanguage,
                    tabBarHeight: 88)
                .opacity(selectedTab == 1 ? 1 : 0)
                .allowsHitTesting(selectedTab == 1)

            CalendarView(themeAccent: themeAccent, themeBackground: themeBackground,
                         distanceUnit: distanceUnit, appLanguage: appLanguage,
                         allSessions: allSessions,
                         tabBarHeight: 88)
                .opacity(selectedTab == 2 ? 1 : 0)
                .allowsHitTesting(selectedTab == 2)

            SettingsTabView(
                storeManager: storeManager,
                accent: $themeAccent,
                background: $themeBackground,
                distanceUnit: $distanceUnit,
                notificationSettings: $notificationSettings,
                language: $appLanguage,
                goalType: $goalType,
                goalTarget: $goalTarget,
                showHelpSheet: $showHelpSheet,
                showOnboarding: $showOnboarding,
                onSettingsChanged: {
                    rescheduleNotifications()
                    loadData()
                    WidgetCenter.shared.reloadAllTimelines()
                },
                onReset: {
                    loadData()
                    WidgetCenter.shared.reloadAllTimelines()
                },
                onSyncHealthKit: syncWithHealthKit,
                onSetGoal: { showGoalSheet = true },
                isSyncing: isSyncing,
                tabBarHeight: 88
            )
            .opacity(selectedTab == 3 ? 1 : 0)
            .allowsHitTesting(selectedTab == 3)
        }
        .ignoresSafeArea(edges: .bottom)
        .environmentObject(themeStore)
        .onChange(of: themeAccent) { themeStore.update(accent: themeAccent, background: themeBackground) }
        .onChange(of: themeBackground) { themeStore.update(accent: themeAccent, background: themeBackground) }
        .overlay(alignment: .bottom) {
            FloatingTabBar(
                selectedTab: $selectedTab,
                isDark: themeBackground.isDark,
                appBg: cBg,
                cardBg: cCard,
                primaryColor: cAccent,
                primarySoft: cAccent.opacity(0.12),
                inkLow: cSub
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(
                language: $appLanguage,
                cAccent: cAccent, cBg: cBg, cCard: cCard, cText: cText, cSub: cSub
            ) {
                UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                showOnboarding = false
                loadData()
                // 온보딩 완료 직후 알림 권한 요청 (daily reminder 기본 ON)
                NotificationManager.shared.requestAuthorization { _ in
                    rescheduleNotifications()
                }
            }
        }
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "onboardingCompleted") {
                appLanguage = SharedDataManager.shared.getLanguage()
                showOnboarding = true
            } else {
                // 기존 사용자 커버: 아직 권한을 안 물어봤고 알림이 켜져 있으면 1회 요청
                if SharedDataManager.shared.getNotificationSettings().isEnabled {
                    NotificationManager.shared.requestAuthorizationIfNotDetermined { granted in
                        if granted { rescheduleNotifications() }
                    }
                }
            }
        }
    }

    // MARK: - 대시보드 탭 콘텐츠

    private func dashboardTab() -> some View {
        NavigationStack {
            ZStack {
                cBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        monthNavigator

                        mileageGoalBanner

                        dailyBarChart

                        monthlySummaryCards

                        if let sync = lastSync {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .medium))
                                Text("\(t(.lastSyncLabel)) · \(sync.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.pretendard(.medium, size: 11))
                            }
                            .foregroundColor(cSub)
                            .padding(.bottom, 4)
                        }

                        Color.clear.frame(height: 96)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
                .background(cBg)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(themeBackground.colorScheme)
            .onAppear { loadData(); autoRefreshIfAuthorized(); fetchAllSessions() }
            .sheet(isPresented: $showGoalSheet) {
            GoalSettingView(
                goalType: goalType,
                goalInput: "\(Int(goalTarget))",
                frequency: runFrequency,
                distanceUnit: distanceUnit,
                language: appLanguage
            ) { newType, newTarget, newFrequency in
                SharedDataManager.shared.saveGoal(type: newType, target: newTarget)
                SharedDataManager.shared.saveRunFrequency(newFrequency)
                goalType     = newType
                goalTarget   = newTarget
                runFrequency = newFrequency
                loadData()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .sheet(isPresented: $showHelpSheet) {
            HelpView(language: appLanguage,
                     cAccent: cAccent, cBg: cBg, cCard: cCard, cText: cText, cSub: cSub)
        }
        .fullScreenCover(isPresented: $showCelebration) {
            CelebrationView(
                primaryValue: celebrationPrimaryValue,
                primaryUnit: celebrationPrimaryUnit,
                monthLabel: selectedMonthString,
                goalTarget: goalTarget,
                sessionCount: monthSessionCount,
                streak: computeStreak()
            ) {
                showCelebration = false
            }
        }
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastMessage)
                    .font(.pretendard(.medium, size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.78))
                    .cornerRadius(24)
                    .padding(.bottom, 100)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showToast)
    }
    }

    // MARK: - 월 네비게이터 (HMG Card Chevrons)

    private var chevronCardShadow: Color {
        themeBackground.isDark ? .black.opacity(0.4) : Color(hex: "#0D1220").opacity(0.04)
    }

    private var monthNavigator: some View {
        HStack {
            // Left chevron card
            Button(action: { navigateMonth(delta: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(cText)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cCard)
                            .shadow(color: chevronCardShadow, radius: 2, x: 0, y: 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        themeBackground.isDark ? Color.white.opacity(0.05) : Color(hex: "#0D1220").opacity(0.04),
                                        lineWidth: 1
                                    )
                            )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            // Month + date info
            VStack(spacing: 2) {
                Text(selectedMonthString)
                    .font(.pretendard(.bold, size: 16))
                    .foregroundColor(cText)
                if isCurrentMonth {
                    Text("Today · \(todayDayString)")
                        .font(.pretendard(.medium, size: 11))
                        .foregroundColor(cSub)
                }
            }

            Spacer()

            // Right chevron card (disabled when at current month)
            Button(action: { navigateMonth(delta: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(canGoForward ? cText : themeBackground.inkOff)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cCard)
                            .shadow(color: chevronCardShadow, radius: 2, x: 0, y: 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        themeBackground.isDark ? Color.white.opacity(0.05) : Color(hex: "#0D1220").opacity(0.04),
                                        lineWidth: 1
                                    )
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 목표 히어로 카드 (Navy Gradient · GoalProgressRing)

    private var goalProgressValue: Double {
        switch goalType {
        case .distance: return min(monthDisplayDistance / goalTarget, 1.0)
        case .calories: return min(monthTotalCalories / goalTarget, 1.0)
        case .duration: return min((monthTotalDurationMin / 60) / goalTarget, 1.0)
        }
    }

    private var goalCurrentStr: String {
        switch goalType {
        case .distance:
            return String(format: "%.1f", monthDisplayDistance)
        case .calories:
            return String(format: "%.0f", monthTotalCalories)
        case .duration:
            let h = Int(monthTotalDurationMin / 60)
            let m = Int(monthTotalDurationMin.truncatingRemainder(dividingBy: 60))
            return h > 0 ? "\(h)h \(m)m" : "\(m)m"
        }
    }

    private var goalTargetStr: String {
        switch goalType {
        case .distance: return "/ \(Int(goalTarget)) \(distanceUnit.symbol)"
        case .calories: return "/ \(Int(goalTarget)) kcal"
        case .duration: return "/ \(Int(goalTarget)) \(t(.durationUnit))"
        }
    }

    // Accent-linked vivid gradient for the hero banner
    private var heroBannerColors: [Color] {
        switch themeAccent {
        case .blue:   return [Color(hex: "#2563EB"), Color(hex: "#1746B0")]
        case .green:  return [Color(hex: "#0DC450"), Color(hex: "#04B249")]
        case .orange: return [Color(hex: "#FF8A30"), Color(hex: "#FD6A00")]
        case .red:    return [Color(hex: "#F75050"), Color(hex: "#D42020")]
        case .purple: return [Color(hex: "#B266EE"), Color(hex: "#7C22C8")]
        case .yellow: return [Color(hex: "#ffcb31"), Color(hex: "#eeac04")]
        }
    }

    private var mileageGoalBanner: some View {
        let isDark = themeBackground.isDark
        return HStack(alignment: .center, spacing: 18) {
            GoalProgressRing(progress: goalProgressValue, isDark: isDark)
                .frame(width: 132, height: 132)

            VStack(alignment: .leading, spacing: 6) {
                EyebrowLabel(text: t(.mileageGoalLabel), color: .white.opacity(0.55))

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(goalCurrentStr)
                        .font(.pretendard(.bold, size: 28))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    Text(goalTargetStr)
                        .font(.pretendard(.medium, size: 15))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }

                if isCurrentMonth {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .medium))
                        Text(String(format: t(.daysLeftFmt), remainingDays))
                            .font(.pretendard(.medium, size: 12))
                    }
                    .foregroundColor(.white.opacity(0.78))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: heroBannerColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: themeAccent.color.opacity(0.30),
                    radius: 7, x: 0, y: 2
                )
        )
    }

    // MARK: - 일별 바 차트

    private var daysInSelectedMonth: Int {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = selectedMonth
        comps.day = 1
        guard let date = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    /// 일별 데이터 배열 (chartMetric에 따라)
    private var dailyChartData: [Double] {
        let cal = Calendar.current
        let days = daysInSelectedMonth
        var result = Array(repeating: 0.0, count: days)
        for session in selectedMonthSessions {
            let day = cal.component(.day, from: session.date)
            guard day >= 1 && day <= days else { continue }
            switch chartMetric {
            case .distance:
                result[day - 1] += session.distanceKm * distanceUnit.conversionFromKm
            case .duration:
                result[day - 1] += session.durationMinutes
            case .calories:
                result[day - 1] += session.calories
            }
        }
        return result
    }

    private var dailyBarChart: some View {
        let data = dailyChartData
        let maxVal = data.max() ?? 0
        let chartMax = maxVal > 0 ? maxVal * 1.25 : 1
        let totalDays = daysInSelectedMonth
        let cal = Calendar.current
        let todayDay: Int? = isCurrentMonth ? cal.component(.day, from: Date()) : nil

        // 사분위수 값 (Y축 기준)
        let q1 = chartMax * 0.25
        let q2 = chartMax * 0.50
        let q3 = chartMax * 0.75

        let yAxisW: CGFloat = 26

        return VStack(spacing: 0) {
            // MARK: 지표 탭
            HStack(spacing: 0) {
                ForEach(ChartMetric.allCases, id: \.self) { metric in
                    Button {
                        chartMetric = metric
                    } label: {
                        VStack(spacing: 6) {
                            Text(metric.label(lang: appLanguage))
                                .font(.pretendard(chartMetric == metric ? .bold : .medium, size: 13))
                                .foregroundColor(chartMetric == metric ? cText : cSub)
                            Rectangle()
                                .fill(chartMetric == metric ? cAccent : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // MARK: 차트 영역
            GeometryReader { geo in
                let chartW = geo.size.width - yAxisW - 16  // 16 = right padding
                let chartH = geo.size.height - 24  // 24 = bottom labels
                let spacing: CGFloat = totalDays > 28 ? 1 : 1.5
                let totalSpacing = spacing * CGFloat(totalDays - 1)
                let barW = max((chartW - totalSpacing) / CGFloat(totalDays), 2)

                ZStack(alignment: .topLeading) {
                    // Y축 레이블 + 가로선
                    ForEach([0.0, q1, q2, q3], id: \.self) { qVal in
                        let yRatio = 1.0 - (qVal / chartMax)
                        let yPos = CGFloat(yRatio) * chartH

                        // 가로선
                        Path { path in
                            path.move(to: CGPoint(x: yAxisW, y: yPos))
                            path.addLine(to: CGPoint(x: yAxisW + chartW, y: yPos))
                        }
                        .stroke(cGray.opacity(qVal == 0 ? 0 : 0.4), lineWidth: 0.5)

                        // Y축 레이블
                        Text(chartYLabel(qVal))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(cSub)
                            .frame(width: yAxisW - 4, alignment: .trailing)
                            .position(x: (yAxisW - 4) / 2, y: yPos)
                    }

                    // Y축 세로선
                    Path { path in
                        path.move(to: CGPoint(x: yAxisW, y: 0))
                        path.addLine(to: CGPoint(x: yAxisW, y: chartH))
                    }
                    .stroke(cSub.opacity(0.3), lineWidth: 1)

                    // X축 가로선 (바닥)
                    Path { path in
                        path.move(to: CGPoint(x: yAxisW, y: chartH))
                        path.addLine(to: CGPoint(x: yAxisW + chartW, y: chartH))
                    }
                    .stroke(cSub.opacity(0.3), lineWidth: 1)

                    // 바 차트
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(0..<totalDays, id: \.self) { i in
                            let val = data[i]
                            let ratio = val / chartMax
                            let barH = max(CGFloat(ratio) * chartH, val > 0 ? 2 : 0)
                            let isToday = todayDay != nil && (i + 1) == todayDay

                            RoundedRectangle(cornerRadius: barW > 5 ? 2 : 1)
                                .fill(isToday ? cAccent : (val > 0 ? cAccent.opacity(0.6) : Color.clear))
                                .frame(width: barW, height: barH)
                        }
                    }
                    .frame(height: chartH, alignment: .bottom)
                    .offset(x: yAxisW)

                    // X축 레이블
                    xAxisLabels(chartW: chartW, chartH: chartH, yAxisW: yAxisW, totalDays: totalDays)
                }
            }
            .aspectRatio(1.6, contentMode: .fit)
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .background(cCard)
        .cornerRadius(18)
    }

    private func chartYLabel(_ value: Double) -> String {
        if value == 0 { return "0" }
        switch chartMetric {
        case .distance:
            return value >= 10 ? String(format: "%.0f", value) : String(format: "%.1f", value)
        case .duration:
            return value >= 10 ? "\(Int(ceil(value / 10)) * 10)" : "\(Int(ceil(value)))"
        case .calories:
            return value >= 10 ? "\(Int(ceil(value / 10)) * 10)" : "\(Int(ceil(value)))"
        }
    }

    private func xAxisLabels(chartW: CGFloat, chartH: CGFloat, yAxisW: CGFloat, totalDays: Int) -> some View {
        // 1, 5, 10, 15, 20[, 25] + 마지막 날 (25는 마지막 날과 4일 이상 차이날 때만)
        var labelDays: [Int] = [1, 5, 10, 15, 20]
        if totalDays - 25 >= 4 { labelDays.append(25) }
        if totalDays == 31 {
            labelDays.append(31)
        } else {
            labelDays.append(totalDays)
        }

        return ForEach(labelDays, id: \.self) { day in
            let x = yAxisW + (CGFloat(day - 1) + 0.5) * (chartW / CGFloat(totalDays))
            Text("\(day)")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(cSub)
                .position(x: x, y: chartH + 12)
        }
    }

    // MARK: - 월간 요약 카드 (2×3 StatChip Grid)

    private var monthlySummaryCards: some View {
        let isDark     = themeBackground.isDark
        let chipAccent = isDark ? themeAccent.colorDark : themeAccent.color
        let chipSoft   = chipAccent.opacity(0.12)
        let chipBg     = themeBackground.cardBg

        let chips: [(icon: String, value: String, unit: String, label: String)] = [
            ("figure.run",       String(format: "%.1f", monthDisplayDistance),     distanceUnit.symbol,       t(.dashboardTotalDistance)),
            ("clock",            monthDurationStr,                                  "",                        t(.dashboardTotalDuration)),
            ("flame.fill",       String(format: "%.0f", monthTotalCalories),       "kcal",                    t(.dashboardTotalCalories)),
            ("number",           "\(monthSessionCount)",                            "",                        t(.thisMonthActivities)),
            ("speedometer",      monthAvgPaceStr,                                   "/\(distanceUnit.symbol)", t(.dashboardAvgPace)),
            ("arrow.left.arrow.right", String(format: "%.1f", monthAvgDistancePerRun), distanceUnit.symbol,   t(.dashboardAvgDistance)),
        ]

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                StatChip(
                    icon: chip.icon,
                    value: chip.value,
                    unit: chip.unit,
                    label: chip.label,
                    accentColor: chipAccent,
                    accentSoft: chipSoft,
                    isDark: isDark,
                    cardBg: chipBg
                )
            }
        }
    }

    // MARK: - HealthKit 동기화

    private func syncWithHealthKit() {
        if HealthKitService.shared.hasRequestedAuthorization() {
            isSyncing = true
            HealthKitService.shared.fetchMonthlyRunningStats { success in
                isSyncing = false
                if success { postSyncUpdate(showToast: true) }
            }
        } else {
            HealthKitService.shared.requestAuthorization { success in
                isAuthorized = success
                if success {
                    isSyncing = true
                    HealthKitService.shared.fetchMonthlyRunningStats { fetchSuccess in
                        isSyncing = false
                        if fetchSuccess { postSyncUpdate(showToast: true) }
                    }
                }
            }
        }
    }

    private func postSyncUpdate(showToast: Bool = false) {
        rescheduleNotifications()
        loadData()
        fetchAllSessions()
        WidgetCenter.shared.reloadAllTimelines()
        if showToast { showToastBanner(t(.syncCompleted)) }
        checkForGoalCelebration()
    }

    private func fetchAllSessions() {
        guard !isLoadingSessions else { return }
        isLoadingSessions = true
        HealthKitService.shared.fetchAllRunningSessions { sessions in
            allSessions = sessions
            isLoadingSessions = false
            let settings = SharedDataManager.shared.getNotificationSettings()
            NotificationManager.shared.scheduleDailyReminder(
                hasRunToday: hasRunToday(),
                settings: settings
            )
        }
    }

    private func showToastBanner(_ msg: String) {
        toastMessage = msg
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showToast = false }
        }
    }

    private func autoRefreshIfAuthorized() {
        guard HealthKitService.shared.hasRequestedAuthorization() else {
            isAuthorized = false
            return
        }
        isAuthorized = true
        guard !isSyncing else { return }
        isSyncing = true
        HealthKitService.shared.fetchMonthlyRunningStats { success in
            isSyncing = false
            if success { postSyncUpdate() }
        }
    }

    // MARK: - 알림 재스케줄

    private func rescheduleNotifications() {
        let settings = SharedDataManager.shared.getNotificationSettings()
        NotificationManager.shared.scheduleDailyReminder(
            hasRunToday: hasRunToday(),
            settings: settings
        )
    }

    private func hasRunToday() -> Bool {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return allSessions.contains { Calendar.current.startOfDay(for: $0.date) == todayStart }
    }

    // MARK: - Streak helper (used by CelebrationView)

    private func computeStreak() -> Int { streakFromSessions(allSessions) }

    private func checkForGoalCelebration() {
        guard isCurrentMonth, goalTarget > 0 else { return }
        let key = "celebratedMonth_\(selectedYear)-\(selectedMonth)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let currentValue: Double
        switch goalType {
        case .distance: currentValue = monthTotalDistanceKm * distanceUnit.conversionFromKm
        case .calories: currentValue = monthTotalCalories
        case .duration: currentValue = monthTotalDurationMin / 60
        }
        guard currentValue >= goalTarget else { return }
        UserDefaults.standard.set(true, forKey: key)
        DispatchQueue.main.async {
            showCelebration = true
        }
    }

    private func loadData() {
        let stats        = SharedDataManager.shared.getMonthlyStats()
        monthlyStats     = stats
        goalType         = SharedDataManager.shared.getGoalType()
        goalTarget       = SharedDataManager.shared.getGoalTarget()
        runFrequency     = SharedDataManager.shared.getRunFrequency()
        themeAccent      = SharedDataManager.shared.getThemeAccent()
        themeBackground  = SharedDataManager.shared.getThemeBackground()
        distanceUnit     = SharedDataManager.shared.getDistanceUnit()
        appLanguage      = SharedDataManager.shared.getLanguage()
        notificationSettings = SharedDataManager.shared.getNotificationSettings()

        lastSync        = stats?.lastSyncTime
        isAuthorized    = HealthKitService.shared.hasRequestedAuthorization()
        applyNavBarStyle()
        checkForGoalCelebration()
        themeStore.syncFromStore()
    }

    // iOS large title ≈ 34pt → 15% reduction = ~29pt
    private func applyNavBarStyle() {
        let isDark = themeBackground.isDark
        let bgColor = isDark
            ? UIColor(red: 11/255, green: 13/255, blue: 18/255, alpha: 1)   // #0B0D12
            : UIColor(red: 232/255, green: 234/255, blue: 237/255, alpha: 1) // #E8EAED
        let titleColor = isDark
            ? UIColor(red: 0.949, green: 0.953, blue: 0.961, alpha: 1)      // #F2F3F5
            : UIColor(red: 0.055, green: 0.067, blue: 0.086, alpha: 1)      // #0E1116
        let largeFont = UIFont(name: "Pretendard-Bold", size: 29)
            ?? UIFont.boldSystemFont(ofSize: 29)
        let inlineFont = UIFont(name: "Pretendard-SemiBold", size: 15)
            ?? UIFont.systemFont(ofSize: 15, weight: .semibold)

        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithOpaqueBackground()
        standardAppearance.backgroundColor = bgColor
        standardAppearance.shadowColor = .clear
        standardAppearance.largeTitleTextAttributes = [.font: largeFont, .foregroundColor: titleColor]
        standardAppearance.titleTextAttributes      = [.font: inlineFont, .foregroundColor: titleColor]

        let scrollEdgeAppearance = UINavigationBarAppearance()
        scrollEdgeAppearance.configureWithTransparentBackground()
        scrollEdgeAppearance.largeTitleTextAttributes = [.font: largeFont, .foregroundColor: titleColor]
        scrollEdgeAppearance.titleTextAttributes      = [.font: inlineFont, .foregroundColor: titleColor]

        UINavigationBar.appearance().standardAppearance   = standardAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdgeAppearance
        UINavigationBar.appearance().compactAppearance    = standardAppearance
    }
}

// MARK: - 도움말 뷰

struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    let language: AppLanguage
    let cAccent: Color
    let cBg: Color
    let cCard: Color
    let cText: Color
    let cSub: Color

    @State private var startExpanded = false
    @State private var featuresExpanded = false
    @State private var widgetExpanded = false
    @State private var tipsExpanded = false

    private func t(_ key: LK) -> String { L(key, language) }

    var body: some View {
        NavigationStack {
            ZStack {
                cBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        AccordionSection(
                            icon: "play.circle.fill",
                            iconColor: Color(hex: "#4ade80"),
                            iconBgColor: Color(hex: "#16a34a").opacity(0.13),
                            title: t(.helpSectionStart),
                            isExpanded: $startExpanded,
                            cCard: cCard,
                            cText: cText
                        ) {
                            VStack(spacing: 0) {
                                helpStepRow(num: "1", title: t(.helpStep1Title), desc: t(.helpStep1Desc))
                                helpDivider
                                helpStepRow(num: "2", title: t(.helpStep2Title), desc: t(.helpStep2Desc))
                                helpDivider
                                helpStepRow(num: "3", title: t(.helpStep3Title), desc: t(.helpStep3Desc))
                            }
                        }
                        AccordionSection(
                            icon: "star.fill",
                            iconColor: Color(hex: "#60a5fa"),
                            iconBgColor: Color(hex: "#2563eb").opacity(0.13),
                            title: t(.helpSectionFeatures),
                            isExpanded: $featuresExpanded,
                            cCard: cCard,
                            cText: cText
                        ) {
                            VStack(spacing: 0) {
                                helpFeatureRow(icon: "flag.checkered", iconColor: Color(hex: "#F5C800"), iconBg: Color(hex: "#F5C800").opacity(0.13), title: t(.helpFeatGoalTitle), desc: t(.helpFeatGoalDesc))
                                helpDivider
                                helpFeatureRow(icon: "arrow.2.circlepath", iconColor: Color(hex: "#4ade80"), iconBg: Color(hex: "#4ade80").opacity(0.13), title: t(.helpFeatFreqTitle), desc: t(.helpFeatFreqDesc))
                                helpDivider
                                helpFeatureRow(icon: "ruler", iconColor: Color(hex: "#60a5fa"), iconBg: Color(hex: "#60a5fa").opacity(0.13), title: t(.helpFeatUnitTitle), desc: t(.helpFeatUnitDesc))
                            }
                        }
                        AccordionSection(
                            icon: "bell.and.waves.left.and.right.fill",
                            iconColor: Color(hex: "#a78bfa"),
                            iconBgColor: Color(hex: "#7c3aed").opacity(0.13),
                            title: t(.helpSectionWidget),
                            isExpanded: $widgetExpanded,
                            cCard: cCard,
                            cText: cText
                        ) {
                            VStack(spacing: 0) {
                                helpFeatureRow(icon: "square.grid.2x2.fill", iconColor: Color(hex: "#a78bfa"), iconBg: Color(hex: "#a78bfa").opacity(0.13), title: t(.helpWidgetTitle), desc: t(.helpWidgetDesc))
                                helpDivider
                                helpFeatureRow(icon: "bell.fill", iconColor: Color(hex: "#fb923c"), iconBg: Color(hex: "#fb923c").opacity(0.13), title: t(.helpNotifTitle), desc: t(.helpNotifDesc))
                            }
                        }
                        AccordionSection(
                            icon: "lightbulb.fill",
                            iconColor: Color(hex: "#fbbf24"),
                            iconBgColor: Color(hex: "#ca8a04").opacity(0.13),
                            title: t(.helpSectionTips),
                            isExpanded: $tipsExpanded,
                            cCard: cCard,
                            cText: cText
                        ) {
                            VStack(alignment: .leading, spacing: 0) {
                                helpTipRow(text: t(.helpTip1))
                                helpTipRow(text: t(.helpTip2))
                                helpTipRow(text: t(.helpTip3))
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(t(.helpTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t(.cancelButton)) { dismiss() }
                        .foregroundColor(cAccent)
                        .bold()
                }
            }
        }
        .preferredColorScheme(nil)
    }

    private var helpDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    private func helpRow<Badge: View>(title: String, desc: String, @ViewBuilder badge: () -> Badge) -> some View {
        HStack(alignment: .top, spacing: 10) {
            badge().padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.pretendard(.bold, size: 13))
                    .foregroundColor(cText)
                Text(desc)
                    .font(.pretendard(.regular, size: 12))
                    .foregroundColor(cSub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func helpStepRow(num: String, title: String, desc: String) -> some View {
        helpRow(title: title, desc: desc) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#F5C800"))
                    .frame(width: 20, height: 20)
                Text(num)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(hex: "#111111"))
            }
        }
    }

    private func helpFeatureRow(icon: String, iconColor: Color, iconBg: Color, title: String, desc: String) -> some View {
        helpRow(title: title, desc: desc) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconBg)
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)
            }
        }
    }

    private func helpTipRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color(hex: "#F5C800"))
                .frame(width: 5, height: 5)
                .padding(.top, 5)
            Text(text)
                .font(.pretendard(.regular, size: 12))
                .foregroundColor(cSub)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Help Accordion Section

private struct AccordionSection<Content: View>: View {
    let icon: String
    let iconColor: Color
    let iconBgColor: Color
    let title: String
    @Binding var isExpanded: Bool
    let cCard: Color
    let cText: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(iconBgColor)
                            .frame(width: 28, height: 28)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    Text(title)
                        .font(.pretendard(.bold, size: 15))
                        .foregroundColor(cText)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.horizontal, 14)
                    content()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(cCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 목표 설정 시트

struct GoalSettingView: View {
    @Environment(\.dismiss) var dismiss
    var onSave: (GoalType, Double, RunFrequency) -> Void

    @State private var selectedGoalType: GoalType
    @State private var goalInput: String
    @State private var selectedFrequency: RunFrequency
    @State private var showInputError = false

    let distanceUnit: DistanceUnit
    let language: AppLanguage

    init(goalType: GoalType, goalInput: String, frequency: RunFrequency,
         distanceUnit: DistanceUnit, language: AppLanguage,
         onSave: @escaping (GoalType, Double, RunFrequency) -> Void) {
        self._selectedGoalType  = State(initialValue: goalType)
        self._goalInput         = State(initialValue: goalInput)
        self._selectedFrequency = State(initialValue: frequency)
        self.distanceUnit       = distanceUnit
        self.language           = language
        self.onSave = onSave
    }

    private func t(_ key: LK) -> String { L(key, language) }
    private var inputUnit: String { selectedGoalType.displayUnit(distanceUnit: distanceUnit, lang: language) }

    private var inputPlaceholder: String {
        switch selectedGoalType {
        case .distance: return distanceUnit == .km ? t(.placeholderDistKm) : t(.placeholderDistMile)
        case .calories: return t(.placeholderCal)
        case .duration: return t(.placeholderDur)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $selectedGoalType) {
                        ForEach(GoalType.allCases, id: \.self) { type in
                            Text(type.localizedDisplayName(lang: language)).tag(type)
                        }
                    } label: {
                        Text(t(.goalTypeSection))
                    }
                    .onChange(of: selectedGoalType) { showInputError = false }

                    HStack {
                        Text(t(.goalTargetSection))
                        Spacer()
                        TextField(inputPlaceholder, text: $goalInput)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                            .onChange(of: goalInput) { showInputError = false }
                        Text(inputUnit)
                            .foregroundColor(.secondary)
                    }

                    if showInputError {
                        Text(t(.inputErrorMsg))
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }

                    Picker(selection: $selectedFrequency) {
                        ForEach(RunFrequency.allCases, id: \.self) { freq in
                            Text(freq.localizedLabel(lang: language)).tag(freq)
                        }
                    } label: {
                        Text(t(.runFreqSection))
                    }
                }
            }
            .navigationTitle(t(.goalNavTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(t(.cancelButton)) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t(.saveButton)) {
                        guard let val = Double(goalInput), val > 0 else {
                            showInputError = true
                            return
                        }
                        onSave(selectedGoalType, val, selectedFrequency)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - 설정 탭

struct SettingsTabView: View {
    @ObservedObject var storeManager: StoreManager

    @Binding var accent: ThemeAccent
    @Binding var background: ThemeBackground
    @Binding var distanceUnit: DistanceUnit
    @Binding var notificationSettings: NotificationSettings
    @Binding var language: AppLanguage
    @Binding var goalType: GoalType
    @Binding var goalTarget: Double
    @Binding var showHelpSheet: Bool
    @Binding var showOnboarding: Bool

    var onSettingsChanged: () -> Void
    var onReset: () -> Void
    var onSyncHealthKit: () -> Void
    var onSetGoal: () -> Void
    var isSyncing: Bool
    var tabBarHeight: CGFloat = 88

    @State private var isReconnecting = false
    @State private var showHKGuideAlert = false
    @State private var showResetConfirm = false
    @State private var notifAuthStatus: String = ""
    @State private var settingsToastMsg: String = ""
    @State private var settingsShowToast: Bool = false
    @State private var widgetBgPreview: UIImage? = SharedDataManager.shared.loadWidgetBackgroundImage()
    @State private var selectedWidgetDesign: WidgetDesign = SharedDataManager.shared.getWidgetDesign()
    @State private var isRestoring: Bool = false
    @State private var workoutSourcePref: WorkoutSourcePreference = SharedDataManager.shared.getWorkoutSourcePreference()
    @State private var showSourceFilterSheet: Bool = false
    @State private var showLocalHelpSheet: Bool = false

    private func t(_ key: LK) -> String { L(key, language) }

    private var accentColor: Color { accent.color }

    private var availableAccents: [ThemeAccent] {
        ThemeAccent.allCases
    }

    private var sourceFilterSummary: String {
        let pref = workoutSourcePref
        guard pref.isConfigured && !pref.allowedBundleIDs.isEmpty else {
            return L(.dataSourceAll, language)
        }
        let count = pref.allowedBundleIDs.count
        return count == 1
            ? "\(count) \(L(.dataSourceSelectedSingular, language))"
            : "\(count) \(L(.dataSourceSelectedPlural, language))"
    }

    /// 설정 변경 시 즉시 저장
    private func saveAll() {
        SharedDataManager.shared.saveTheme(accent: accent, background: background)
        SharedDataManager.shared.saveDistanceUnit(distanceUnit)
        SharedDataManager.shared.saveNotificationSettings(notificationSettings)
        SharedDataManager.shared.saveLanguage(language)
        SharedDataManager.shared.saveWidgetDesign(selectedWidgetDesign)
        onSettingsChanged()
    }

    // 알림 시:분을 native DatePicker(Date)와 연결하는 브리지 바인딩
    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents()
                c.hour = notificationSettings.reminderHour
                c.minute = notificationSettings.reminderMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                notificationSettings.reminderHour = c.hour ?? 19
                notificationSettings.reminderMinute = c.minute ?? 0
                saveAll()
            }
        )
    }

    // MARK: - Icon badge helper
    private func settingsIcon(_ systemName: String, _ color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(color)
            .cornerRadius(6)
    }

    // MARK: - Section card builder
    @ViewBuilder
    private func settingsSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.pretendard(.semiBold, size: 11))
                .foregroundColor(background.subText)
                .padding(.horizontal, 4)
            content()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(background.cardBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    background.isDark ? Color.white.opacity(0.05) : Color(hex: "#0D1220").opacity(0.04),
                                    lineWidth: 1
                                )
                        )
                )
        }
    }

    // MARK: - Row divider
    private var rowDivider: some View {
        Rectangle()
            .fill(background.lineColor)
            .frame(height: 0.5)
            .padding(.leading, 54)
    }

    // MARK: - Settings Body
    var body: some View {
        NavigationStack {
            ZStack {
                background.appBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // DATA
                        settingsSection(t(.settingSectionData)) {
                            VStack(spacing: 0) {
                                Button(action: onSetGoal) {
                                    HStack(spacing: 12) {
                                        settingsIcon("target", .orange)
                                        Text(t(.setGoalButton))
                                            .font(.pretendard(.regular, size: 16))
                                            .foregroundColor(background.mainText)
                                        Spacer()
                                        Text("\(goalType.localizedDisplayName(lang: language)) \(formatGoalLabel())")
                                            .font(.pretendard(.regular, size: 14))
                                            .foregroundColor(background.subText)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(background.inkOff)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 13)
                                }
                                .buttonStyle(.plain)
                                rowDivider
                                // 권한 행 — 항상 표시 (권한 허용 / 건강 앱에서 관리)
                                Button(action: {
                                    if HealthKitService.shared.hasRequestedAuthorization() {
                                        showHKGuideAlert = true
                                    } else {
                                        isReconnecting = true
                                        HealthKitService.shared.requestAuthorization { _ in
                                            isReconnecting = false
                                        }
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        settingsIcon("heart.text.square", .red)
                                        Text(t(.allowHealthKit))
                                            .font(.pretendard(.regular, size: 16))
                                            .foregroundColor(background.mainText)
                                        Spacer()
                                        if isReconnecting { ProgressView() }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 13)
                                }
                                .buttonStyle(.plain)
                                .disabled(isReconnecting)
                                rowDivider
                                // 동기화 행 — 항상 표시 (Apple Health 데이터 가져오기)
                                Button(action: onSyncHealthKit) {
                                    HStack(spacing: 12) {
                                        settingsIcon("arrow.clockwise", .red)
                                        Text(isSyncing ? t(.syncingLabel) : t(.syncWithHealthKit))
                                            .font(.pretendard(.regular, size: 16))
                                            .foregroundColor(background.mainText)
                                        Spacer()
                                        if isSyncing { ProgressView() }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 13)
                                }
                                .buttonStyle(.plain)
                                .disabled(isSyncing)
                                rowDivider
                                Button(action: { showSourceFilterSheet = true }) {
                                    HStack(spacing: 12) {
                                        settingsIcon("line.3.horizontal.decrease.circle.fill", .cyan)
                                        Text(L(.dataSourceButton, language))
                                            .font(.pretendard(.regular, size: 16))
                                            .foregroundColor(background.mainText)
                                        Spacer()
                                        Text(sourceFilterSummary)
                                            .font(.pretendard(.regular, size: 14))
                                            .foregroundColor(background.subText)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(background.inkOff)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 13)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // APPEARANCE
                        settingsSection(t(.settingSectionGeneral)) {
                            VStack(spacing: 0) {
                                // Accent colour circles
                                HStack(spacing: 12) {
                                    settingsIcon("paintpalette.fill", Color(hex: "#913DE5"))
                                    Text("Accent")
                                        .font(.pretendard(.regular, size: 16))
                                        .foregroundColor(background.mainText)
                                    Spacer()
                                    HStack(spacing: 7) {
                                        ForEach(availableAccents, id: \.self) { ac in
                                            ZStack {
                                                Circle().fill(ac.color).frame(width: 22, height: 22)
                                                if accent == ac {
                                                    Circle()
                                                        .strokeBorder(background.mainText, lineWidth: 2)
                                                        .frame(width: 22, height: 22)
                                                    Circle().fill(ac.color).frame(width: 15, height: 15)
                                                }
                                            }
                                            .onTapGesture { accent = ac; saveAll() }
                                        }
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 13)
                                rowDivider
                                // Theme
                                HStack(spacing: 12) {
                                    settingsIcon("circle.lefthalf.filled", Color(hex: "#6B7280"))
                                    Text(t(.bgThemeSection))
                                        .font(.pretendard(.regular, size: 16))
                                        .foregroundColor(background.mainText)
                                    Spacer()
                                    Picker("", selection: $background) {
                                        ForEach(ThemeBackground.allCases, id: \.self) { bg in
                                            Text(bg.localizedLabel(lang: language)).tag(bg)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 140)
                                    .onChange(of: background) { saveAll() }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                rowDivider
                                // Distance unit
                                HStack(spacing: 12) {
                                    settingsIcon("ruler", Color(hex: "#0D9488"))
                                    Text(t(.distUnitSection))
                                        .font(.pretendard(.regular, size: 16))
                                        .foregroundColor(background.mainText)
                                    Spacer()
                                    Picker("", selection: $distanceUnit) {
                                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                                            Text(unit.symbol).tag(unit)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 100)
                                    .onChange(of: distanceUnit) { oldUnit, newUnit in
                                        if goalType == .distance {
                                            // oldUnit 기준으로 변환 방향을 결정 — 이중 변환 방지
                                            let converted = oldUnit == .km
                                                ? goalTarget * DistanceUnit.mile.conversionFromKm
                                                : goalTarget / DistanceUnit.mile.conversionFromKm
                                            goalTarget = converted
                                            SharedDataManager.shared.saveGoal(type: goalType, target: converted)
                                        }
                                        saveAll()
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                rowDivider
                                // Language
                                HStack(spacing: 12) {
                                    settingsIcon("globe", Color(hex: "#3478FE"))
                                    Text(t(.languageSection))
                                        .font(.pretendard(.regular, size: 16))
                                        .foregroundColor(background.mainText)
                                    Spacer()
                                    Picker("", selection: $language) {
                                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                                            Text(lang.displayName).tag(lang)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .accentColor(background.subText)
                                    .onChange(of: language) { saveAll() }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                            }
                        }

                        // WIDGET
                        settingsSection(t(.settingSectionWidget)) {
                            VStack(spacing: 0) {
                                NavigationLink {
                                    WidgetDesignPickerView(
                                        selectedDesign: $selectedWidgetDesign,
                                        accent: accentColor,
                                        bg: background,
                                        language: language,
                                        onChanged: saveAll
                                    )
                                } label: {
                                    HStack(spacing: 12) {
                                        settingsIcon("square.grid.2x2.fill", Color(hex: "#5856D6"))
                                        Text(t(.widgetDesignSection))
                                            .font(.pretendard(.regular, size: 16))
                                            .foregroundColor(background.mainText)
                                        Spacer()
                                        Text(selectedWidgetDesign.localizedLabel(lang: language))
                                            .font(.pretendard(.regular, size: 14))
                                            .foregroundColor(background.subText)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(background.inkOff)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 13)
                                }
                                if storeManager.isPro {
                                    rowDivider
                                    NavigationLink {
                                        PhotoGalleryView(
                                            accentColor: accentColor,
                                            bg: background,
                                            language: language
                                        )
                                    } label: {
                                        HStack(spacing: 12) {
                                            settingsIcon("photo.on.rectangle", Color(hex: "#3478FE"))
                                            Text(t(.widgetBgSelectPhoto))
                                                .font(.pretendard(.regular, size: 16))
                                                .foregroundColor(background.mainText)
                                            Spacer()
                                            if let thumb = widgetBgPreview {
                                                Image(uiImage: thumb)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 36, height: 17)
                                                    .clipped()
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(background.inkOff)
                                        }
                                        .padding(.horizontal, 14).padding(.vertical, 13)
                                    }
                                } else {
                                    rowDivider
                                    HStack(spacing: 12) {
                                        settingsIcon("photo.on.rectangle", Color(hex: "#3478FE"))
                                        Text(t(.widgetBgSelectPhoto))
                                            .font(.pretendard(.regular, size: 16))
                                            .foregroundColor(background.mainText)
                                        Spacer()
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(background.inkOff)
                                        Text("Pro")
                                            .font(.pretendard(.semiBold, size: 12))
                                            .foregroundColor(accentColor)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 13)
                                    .opacity(0.65)
                                }
                            }
                        }

                        // NOTIFICATIONS
                        settingsSection(t(.notificationsSection)) {
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    settingsIcon("bell.badge.fill", Color(hex: "#EF4444"))
                                    Text(t(.goalReminderToggle))
                                        .font(.pretendard(.regular, size: 16))
                                        .foregroundColor(background.mainText)
                                    Spacer()
                                    Toggle("", isOn: $notificationSettings.isEnabled)
                                        .tint(accentColor)
                                        .labelsHidden()
                                        .onChange(of: notificationSettings.isEnabled) {
                                            if notificationSettings.isEnabled {
                                                NotificationManager.shared.requestAuthorization { granted in
                                                    if !granted {
                                                        notificationSettings.isEnabled = false
                                                        notifAuthStatus = t(.notifPermError)
                                                    } else {
                                                        notifAuthStatus = ""
                                                    }
                                                }
                                            }
                                            saveAll()
                                        }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 13)
                                if notificationSettings.isEnabled {
                                    rowDivider
                                    HStack {
                                        Text(t(.reminderTimeLabel))
                                            .font(.pretendard(.regular, size: 15))
                                            .foregroundColor(background.mainText)
                                        Spacer()
                                        DatePicker(
                                            "",
                                            selection: reminderTimeBinding,
                                            displayedComponents: .hourAndMinute
                                        )
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .tint(accentColor)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                }
                                if !notifAuthStatus.isEmpty {
                                    rowDivider
                                    Text(notifAuthStatus)
                                        .font(.pretendard(.regular, size: 13))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                }
                            }
                        }

                        // PRO (if not unlocked)
                        if !storeManager.isPro {
                            settingsSection(t(.proSectionTitle)) {
                                VStack(spacing: 0) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(t(.proTagline))
                                            .font(.pretendard(.semiBold, size: 15))
                                            .foregroundColor(background.mainText)
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(accentColor)
                                            Text(t(.proFeaturePhoto))
                                                .font(.pretendard(.regular, size: 15))
                                                .foregroundColor(background.subText)
                                        }
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(accentColor)
                                            Text(t(.proFeatureLockWidget))
                                                .font(.pretendard(.regular, size: 15))
                                                .foregroundColor(background.subText)
                                        }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 14)
                                    rowDivider
                                    Button {
                                        Task {
                                            switch await storeManager.purchasePro() {
                                            case .success:
                                                WidgetCenter.shared.reloadAllTimelines()
                                                showSettingsToast(t(.proPurchased))
                                            case .pending:
                                                showSettingsToast(t(.proPending))
                                            case .unavailable:
                                                showSettingsToast(t(.proLoadFailed))
                                            case .failed:
                                                showSettingsToast(t(.proPurchaseFailed))
                                            case .cancelled:
                                                break
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Spacer()
                                            if storeManager.purchaseInProgress {
                                                ProgressView().tint(.white).padding(.trailing, 8)
                                            }
                                            Text(t(.proUpgradeButton))
                                                .font(.pretendard(.bold, size: 16))
                                            if let price = storeManager.proProduct?.displayPrice {
                                                Text(price)
                                                    .font(.pretendard(.medium, size: 14))
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 14)
                                        .foregroundColor(accent.foregroundColor)
                                        .background(accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(storeManager.purchaseInProgress)
                                    rowDivider
                                    Button(action: {
                                        isRestoring = true
                                        Task {
                                            await storeManager.restorePurchases()
                                            isRestoring = false
                                            if storeManager.isPro {
                                                WidgetCenter.shared.reloadAllTimelines()
                                                showSettingsToast(t(.proRestored))
                                            } else {
                                                showSettingsToast(t(.proRestoreFailed))
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            settingsIcon("arrow.clockwise", Color(hex: "#6B7280"))
                                            Text(t(.proRestoreButton))
                                                .font(.pretendard(.regular, size: 16))
                                                .foregroundColor(background.mainText)
                                            Spacer()
                                            if isRestoring { ProgressView() }
                                        }
                                        .padding(.horizontal, 14).padding(.vertical, 13)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isRestoring)
                                }
                            }
                        }

                        // ABOUT
                        settingsSection(t(.settingSectionAbout)) {
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    settingsIcon("info.circle.fill", Color(hex: "#6B7280"))
                                    Text(t(.versionLabel))
                                        .font(.pretendard(.regular, size: 16))
                                        .foregroundColor(background.mainText)
                                    Spacer()
                                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                                        .font(.pretendard(.regular, size: 14))
                                        .foregroundColor(background.subText)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 13)
                                if storeManager.isPro {
                                    rowDivider
                                    HStack(spacing: 12) {
                                        settingsIcon("crown.fill", Color(hex: "#F59E0B"))
                                        Text(t(.proUnlocked))
                                            .font(.pretendard(.regular, size: 16))
                                            .foregroundColor(accentColor)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 13)
                                }
                                rowDivider
                                Button(action: { showOnboarding = true }) {
                                    HStack(spacing: 12) {
                                        settingsIcon("play.circle.fill", Color(hex: "#0EA5E9"))
                                        Text(t(.replayTutorial))
                                            .font(.pretendard(.regular, size: 16))
                                            .foregroundColor(background.mainText)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(background.inkOff)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 13)
                                }
                                .buttonStyle(.plain)
                                rowDivider
                                Button(action: {
                                    WidgetCenter.shared.reloadAllTimelines()
                                    showSettingsToast(t(.widgetRefreshed))
                                }) {
                                    HStack(spacing: 12) {
                                        settingsIcon("arrow.clockwise.circle", Color(hex: "#04B249"))
                                        Text(t(.forceRefreshWidget))
                                            .font(.pretendard(.regular, size: 16))
                                            .foregroundColor(background.mainText)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 13)
                                }
                                .buttonStyle(.plain)
                                rowDivider
                                Button(action: { showResetConfirm = true }) {
                                    HStack(spacing: 12) {
                                        settingsIcon("trash.fill", Color(hex: "#EF4444"))
                                        Text(t(.resetDataButton))
                                            .font(.pretendard(.regular, size: 16))
                                            .foregroundColor(Color(hex: "#EF4444"))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 13)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Color.clear.frame(height: tabBarHeight)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .onAppear {
                widgetBgPreview = SharedDataManager.shared.loadWidgetBackgroundImage()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showLocalHelpSheet = true }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(accent.color)
                    }
                }
            }
            .preferredColorScheme(background.colorScheme)
            .alert(t(.hkGuideAlertTitle), isPresented: $showHKGuideAlert) {
                Button(t(.hkGuideOpenButton)) {
                    if let url = URL(string: "x-apple-health://") {
                        UIApplication.shared.open(url)
                    }
                }
                Button(t(.cancelButton), role: .cancel) {}
            } message: {
                Text(t(.hkGuideAlertMessage))
            }
            .confirmationDialog(
                t(.resetConfirmMsg),
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button(t(.resetConfirmButton), role: .destructive) {
                    SharedDataManager.shared.resetAll()
                    onReset()
                }
                Button(t(.cancelButton), role: .cancel) {}
            }
            .overlay(alignment: .bottom) {
                if settingsShowToast {
                    Text(settingsToastMsg)
                        .font(.pretendard(.medium, size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Color.black.opacity(0.78))
                        .cornerRadius(24)
                        .padding(.bottom, tabBarHeight + 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: settingsShowToast)
            .sheet(isPresented: $showSourceFilterSheet) {
                DataSourceFilterView(
                    pref: workoutSourcePref,
                    language: language,
                    accentColor: accentColor
                ) { updatedPref in
                    workoutSourcePref = updatedPref
                    SharedDataManager.shared.saveWorkoutSourcePreference(updatedPref)
                    onSettingsChanged()
                    onSyncHealthKit()
                }
            }
            .sheet(isPresented: $showLocalHelpSheet) {
                HelpView(language: language,
                         cAccent: accentColor,
                         cBg: background.appBg,
                         cCard: background.cardBg,
                         cText: background.mainText,
                         cSub: background.subText)
            }
        }
    }

    private func formatGoalLabel() -> String {
        switch goalType {
        case .distance: return "\(Int(goalTarget))\(distanceUnit.symbol)"
        case .calories: return "\(Int(goalTarget))kcal"
        case .duration: return "\(Int(goalTarget))\(t(.durationUnit))"
        }
    }

    private func showSettingsToast(_ msg: String) {
        settingsToastMsg = msg
        withAnimation { settingsShowToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { settingsShowToast = false }
        }
    }
}

// MARK: - 위젯 디자인 선택 뷰

struct WidgetDesignPickerView: View {
    @Binding var selectedDesign: WidgetDesign
    let accent: Color
    let bg: ThemeBackground
    let language: AppLanguage
    var onChanged: () -> Void

    var body: some View {
        Form {
            // 선택된 디자인 프리뷰
            Section {
                WidgetDesignPreview(design: selectedDesign, accent: accent, bg: bg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .cornerRadius(16)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            } header: {
                Text("Preview")
            }

            // 디자인 목록
            Section {
                ForEach(WidgetDesign.allCases, id: \.self) { design in
                    Button {
                        selectedDesign = design
                        SharedDataManager.shared.saveWidgetDesign(design)
                        onChanged()
                    } label: {
                        HStack(spacing: 14) {
                            WidgetDesignPreview(design: design, accent: accent, bg: bg)
                                .frame(width: 80, height: 38)
                                .cornerRadius(8)

                            Text(design.localizedLabel(lang: language))
                                .foregroundColor(.primary)

                            Spacer()

                            if selectedDesign == design {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(L(.widgetDesignSection, language))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 위젯 디자인 미니 프리뷰

struct WidgetDesignPreview: View {
    let design: WidgetDesign
    let accent: Color
    let bg: ThemeBackground

    // 기준 크기 140×66 에서의 스케일 계산
    private let refW: CGFloat = 140
    private let refH: CGFloat = 66

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / refW, geo.size.height / refH)
            ZStack {
                bg.cardBg
                previewContent(scale: s)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private func previewContent(scale s: CGFloat) -> some View {
        let pad = 8 * s
        let sp1 = 1 * s
        let sp3 = 3 * s
        let sp4 = 4 * s

        switch design {
        case .minimal:
            VStack {
                HStack {
                    Text("7/20").font(.system(size: 6 * s, weight: .medium))
                    Spacer()
                }
                Spacer()
                Text("42.5")
                    .font(.system(size: 18 * s, weight: .black))
                + Text(" km").font(.system(size: 8 * s, weight: .semibold))
                Spacer()
            }
            .foregroundColor(bg.mainText)
            .padding(pad)

        case .compact:
            VStack(alignment: .leading, spacing: sp4) {
                HStack {
                    Text("7/20").font(.system(size: 5 * s, weight: .medium))
                    Spacer()
                    Text("11d").font(.system(size: 5 * s, weight: .bold))
                }
                Spacer()
                Text("42.5")
                    .font(.system(size: 14 * s, weight: .black))
                + Text(" km").font(.system(size: 6 * s, weight: .semibold))
                miniBar(progress: 0.42, height: 4 * s)
            }
            .foregroundColor(bg.mainText)
            .padding(pad)

        case .balanced:
            VStack(alignment: .leading, spacing: sp3) {
                HStack {
                    Text("7/20").font(.system(size: 5 * s, weight: .medium))
                    Spacer()
                    Text("11d").font(.system(size: 5 * s, weight: .bold))
                }
                Spacer()
                HStack(alignment: .bottom) {
                    Text("42.5")
                        .font(.system(size: 14 * s, weight: .black))
                    + Text(" km").font(.system(size: 6 * s, weight: .semibold))
                    Spacer()
                    VStack(alignment: .trailing, spacing: sp1) {
                        Text("Mileage").font(.system(size: 4 * s, weight: .medium)).foregroundColor(bg.subText)
                        Text("100km").font(.system(size: 7 * s, weight: .bold))
                    }
                }
                miniBar(progress: 0.42, height: 4 * s)
            }
            .foregroundColor(bg.mainText)
            .padding(pad)

        case .complete:
            VStack(alignment: .leading, spacing: sp3) {
                HStack {
                    Text("7/20").font(.system(size: 5 * s, weight: .medium))
                    Text("·").foregroundColor(bg.subText)
                    Text("11d").font(.system(size: 5 * s, weight: .bold)).foregroundColor(accent)
                    Spacer()
                }
                HStack(spacing: sp4) {
                    (Text("42.5")
                        .font(.system(size: 14 * s, weight: .black))
                    + Text(" km").font(.system(size: 6 * s, weight: .semibold)).foregroundColor(bg.subText))
                    miniBar(progress: 0.42, height: 4 * s)
                }
                HStack {
                    VStack(alignment: .leading, spacing: sp1) {
                        Text("100km").font(.system(size: 5 * s, weight: .bold)).foregroundColor(accent)
                        Text("Mileage").font(.system(size: 4 * s)).foregroundColor(bg.subText)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: sp1) {
                        Text("57.5km").font(.system(size: 5 * s, weight: .bold)).foregroundColor(accent)
                        Text("Left").font(.system(size: 4 * s)).foregroundColor(bg.subText)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: sp1) {
                        Text("5.2km").font(.system(size: 5 * s, weight: .bold)).foregroundColor(accent)
                        Text("/run").font(.system(size: 4 * s)).foregroundColor(bg.subText)
                    }
                }
            }
            .foregroundColor(bg.mainText)
            .padding(pad)
        }
    }

    private func miniBar(progress: Double, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(bg.grayBg)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(accent)
                    .frame(width: geo.size.width * CGFloat(progress))
            }
        }
        .frame(height: height)
    }
}

// MARK: - 위젯 배경 이미지 크롭 뷰

struct WidgetImageCropView: View {
    @Environment(\.dismiss) var dismiss
    let image: UIImage
    let accentColor: Color
    let language: AppLanguage
    var onSave: (UIImage) -> Void

    // Medium 위젯 비율
    private let cropAspect: CGFloat = 360.0 / 169.0

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var currentCropW: CGFloat = 400  // 실제 화면 크롭 폭 (renderCrop 동기화용)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geo in
                    let cropW = geo.size.width - 32
                    let cropH = cropW / cropAspect
                    let fill  = fillSize(cropW: cropW, cropH: cropH)
                    let imgW  = fill.width * scale
                    let imgH  = fill.height * scale

                    VStack(spacing: 16) {
                        Text(L(.widgetCropHint, language))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .frame(width: imgW, height: imgH)
                                .offset(offset)

                            CropOverlay(cropW: cropW, cropH: cropH)
                        }
                        .frame(width: cropW, height: cropH)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    offset = CGSize(
                                        width: lastOffset.width + v.translation.width,
                                        height: lastOffset.height + v.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    clampOffset(cropW: cropW, cropH: cropH)
                                }
                        )
                        .simultaneousGesture(
                            MagnifyGesture()
                                .onChanged { v in
                                    scale = min(max(lastScale * v.magnification, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    clampOffset(cropW: cropW, cropH: cropH)
                                }
                        )
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onAppear { currentCropW = cropW }
                    .onChange(of: geo.size) { currentCropW = geo.size.width - 32 }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L(.cancelButton, language)) { dismiss() }
                        .foregroundColor(.white.opacity(0.8))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L(.widgetCropDone, language)) {
                        onSave(renderCrop())
                        dismiss()
                    }
                    .bold()
                    .foregroundColor(accentColor)
                }
            }
        }
    }

    // MARK: - 이미지가 크롭 영역을 꽉 채우는 크기 (aspect fill, scale=1 기준)

    private func fillSize(cropW: CGFloat, cropH: CGFloat) -> CGSize {
        let imgAspect = image.size.width / image.size.height
        let cAspect   = cropW / cropH
        if imgAspect > cAspect {
            // 이미지가 더 넓음 → 높이 맞춤
            return CGSize(width: cropH * imgAspect, height: cropH)
        } else {
            // 이미지가 더 좁거나 같음 → 너비 맞춤
            return CGSize(width: cropW, height: cropW / imgAspect)
        }
    }

    // MARK: - 바운드 클램핑 (이미지가 크롭 영역 바깥으로 나가지 않게)

    private func clampOffset(cropW: CGFloat, cropH: CGFloat) {
        let fill = fillSize(cropW: cropW, cropH: cropH)
        let imgW = fill.width * scale
        let imgH = fill.height * scale
        let maxX = max((imgW - cropW) / 2, 0)
        let maxY = max((imgH - cropH) / 2, 0)
        withAnimation(.easeOut(duration: 0.2)) {
            offset.width  = min(max(offset.width, -maxX), maxX)
            offset.height = min(max(offset.height, -maxY), maxY)
        }
        lastOffset = offset
    }

    // MARK: - 크롭 렌더링

    private func renderCrop() -> UIImage {
        let cropW = currentCropW
        let cropH = cropW / cropAspect

        let fill = fillSize(cropW: cropW, cropH: cropH)
        let imgW = fill.width * scale
        let imgH = fill.height * scale

        // 이미지 중심은 크롭 중심에서 offset만큼 이동
        // → 이미지 draw origin = (cropW/2 - imgW/2 + offset.width,
        //                         cropH/2 - imgH/2 + offset.height)
        let drawX = (cropW - imgW) / 2 + offset.width
        let drawY = (cropH - imgH) / 2 + offset.height

        // UIGraphicsImageRenderer로 크롭 — orientation 자동 반영
        let outputSize = CGSize(width: cropW, height: cropH)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { _ in
            image.draw(in: CGRect(x: drawX, y: drawY, width: imgW, height: imgH))
        }
    }
}

// MARK: - 크롭 오버레이 (반투명 마스크 + 테두리)

private struct CropOverlay: View {
    let cropW: CGFloat
    let cropH: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Color.white.opacity(0.7), lineWidth: 2)
            .frame(width: cropW, height: cropH)
            .allowsHitTesting(false)
    }
}

// MARK: - DataSourceFilterView

struct DataSourceFilterView: View {
    @Environment(\.dismiss) private var dismiss
    let initialPref: WorkoutSourcePreference
    let language: AppLanguage
    let accentColor: Color
    var onSave: (WorkoutSourcePreference) -> Void

    @State private var availableSources: [(name: String, bundleID: String)] = []
    @State private var selectedBundleIDs: Set<String>
    @State private var isLoading = true

    init(pref: WorkoutSourcePreference, language: AppLanguage,
         accentColor: Color, onSave: @escaping (WorkoutSourcePreference) -> Void) {
        self.initialPref = pref
        self.language = language
        self.accentColor = accentColor
        self.onSave = onSave
        self._selectedBundleIDs = State(initialValue: Set(pref.allowedBundleIDs))
    }

    private var allSelected: Bool { selectedBundleIDs.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        selectedBundleIDs = []
                    } label: {
                        HStack {
                            Text(L(.dataSourceAll, language))
                                .foregroundColor(.primary)
                            Spacer()
                            if allSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text(L(.dataSourceLoading, language))
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                        }
                    }
                } else {
                    Section {
                        ForEach(availableSources, id: \.bundleID) { source in
                            Button {
                                if selectedBundleIDs.contains(source.bundleID) {
                                    selectedBundleIDs.remove(source.bundleID)
                                } else {
                                    selectedBundleIDs.insert(source.bundleID)
                                }
                            } label: {
                                HStack {
                                    Text(source.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedBundleIDs.contains(source.bundleID) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(accentColor)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text(L(.dataSourceSectionHeader, language))
                    } footer: {
                        Text(L(.dataSourceFooter, language))
                            .font(.system(size: 12))
                    }
                }
            }
            .navigationTitle(L(.dataSourceTitle, language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L(.cancelButton, language)) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L(.saveButton, language)) {
                        let pref = WorkoutSourcePreference(
                            allowedBundleIDs: Array(selectedBundleIDs),
                            isConfigured: true
                        )
                        onSave(pref)
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                HealthKitService.shared.fetchAvailableRunningSources { sources in
                    availableSources = sources
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - CalendarView

struct CalendarView: View {
    let themeAccent: ThemeAccent
    let themeBackground: ThemeBackground
    let distanceUnit: DistanceUnit
    let appLanguage: AppLanguage
    let allSessions: [RunSession]
    var tabBarHeight: CGFloat = 88

    @State private var selectedDate: Date = Date()
    @State private var displayMonth: Date = Date()

    private func t(_ key: LK) -> String { L(key, appLanguage) }
    private var cAccent: Color  { themeBackground.isDark ? themeAccent.colorDark : themeAccent.color }
    private var cBg:     Color  { themeBackground.appBg }
    private var cCard:   Color  { themeBackground.cardBg }
    private var cText:   Color  { themeBackground.mainText }
    private var cSub:    Color  { themeBackground.subText }

    var body: some View {
        NavigationStack {
            ZStack {
                cBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        monthPicker

                        VStack(spacing: 12) {
                            weekdayHeader
                            calendarGrid
                            calendarLegend
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(cCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(themeBackground.isDark ? Color.white.opacity(0.05) : Color(hex: "#0D1220").opacity(0.04), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)

                        streakCard
                            .padding(.horizontal, 16)

                        selectedDateSessions
                            .padding(.horizontal, 16)

                        Color.clear.frame(height: tabBarHeight + 8)
                    }
                    .padding(.top, 4)
                }
                .background(cBg)
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(themeBackground.colorScheme)
            .onAppear { focusLastWorkoutOfMonth() }
            .onChange(of: displayMonth) { focusLastWorkoutOfMonth() }
        }
    }

    private var monthPicker: some View {
        let shadowColor: Color = themeBackground.isDark ? .black.opacity(0.4) : Color(hex: "#0D1220").opacity(0.04)
        let borderColor: Color = themeBackground.isDark ? .white.opacity(0.05) : Color(hex: "#0D1220").opacity(0.04)

        return HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(cText)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cCard)
                            .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthYearString(displayMonth))
                .font(.pretendard(.bold, size: 16))
                .foregroundColor(cText)

            Spacer()

            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(canGoToNextMonth() ? cText : themeBackground.inkOff)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cCard)
                            .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canGoToNextMonth())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var weekdayHeader: some View {
        let labels = weekdayLabels()
        return HStack(spacing: 0) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.pretendard(.semiBold, size: 11))
                    .foregroundColor(cSub)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let days = getDaysInMonth()
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: cols, spacing: 4) {
            ForEach(days, id: \.id) { day in
                if let date = day.date {
                    let km = distanceKm(for: date)
                    let isSelected = isSameDay(date, selectedDate)
                    let isRunDay = isToday(date)

                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(intensityColor(km: km))

                        if isSelected {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(cAccent, lineWidth: 2)
                        }

                        Text("\(day.number)")
                            .font(.pretendard(isRunDay ? .bold : .medium, size: 13))
                            .foregroundColor(textColorForIntensity(km: km))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if isToday(date) {
                            Circle()
                                .fill(cAccent)
                                .frame(width: 5, height: 5)
                                .padding(4)
                        }
                    }
                    .frame(height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedDate = date }
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private var calendarLegend: some View {
        let levels: [(color: Color, label: String)] = [
            (themeBackground.grayBg, t(.calLegendRest)),
            (cAccent.opacity(0.25),  "< 3\(distanceUnit.symbol)"),
            (cAccent.opacity(0.55),  "< 6\(distanceUnit.symbol)"),
            (cAccent,                "6+\(distanceUnit.symbol)"),
        ]
        return HStack(spacing: 12) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(item.color)
                        .frame(width: 12, height: 12)
                    Text(item.label)
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(cSub)
                }
            }
            Spacer()
        }
    }

    private var streakCard: some View {
        let streak = currentStreak()
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cAccent.opacity(themeBackground.isDark ? 0.2 : 0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(cAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(streak)")
                        .font(.pretendard(.bold, size: 22))
                        .foregroundColor(cText)
                    Text(streak == 1 ? t(.calStreakDay) : t(.calStreakDays))
                        .font(.pretendard(.medium, size: 12))
                        .foregroundColor(cSub)
                }
                Text(t(.calStreakLabel))
                    .font(.pretendard(.medium, size: 11))
                    .foregroundColor(cSub)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(themeBackground.isDark ? Color.white.opacity(0.05) : Color(hex: "#0D1220").opacity(0.04), lineWidth: 1)
                )
        )
    }

    private var selectedDateSessions: some View {
        let sessions = sessionsForSelectedDate
        let f = DateFormatter()
        f.locale = appLanguage.locale
        f.dateFormat = L(.shortDateFormat, appLanguage)
        let dateLabel = f.string(from: selectedDate)

        return VStack(alignment: .leading, spacing: 10) {
            Text(dateLabel)
                .font(.pretendard(.semiBold, size: 13))
                .foregroundColor(cSub)

            if sessions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 22))
                            .foregroundColor(themeBackground.inkOff)
                        Text(t(.calRestDay))
                            .font(.pretendard(.medium, size: 13))
                            .foregroundColor(themeBackground.inkOff)
                    }
                    .padding(.vertical, 28)
                    Spacer()
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(themeBackground.cardSoft)
                )
            } else {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    NavigationLink {
                        RunSessionDetailView(
                            session: session,
                            runNumber: index + 1,
                            distanceUnit: distanceUnit,
                            appLanguage: appLanguage,
                            themeAccent: themeAccent,
                            themeBackground: themeBackground
                        )
                    } label: {
                        RunSessionCard(
                            session: session,
                            runNumber: index + 1,
                            distanceUnit: distanceUnit,
                            language: appLanguage,
                            themeBackground: themeBackground,
                            cAccent: cAccent,
                            cCard: cCard,
                            cText: cText,
                            cSub: cSub
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func getDaysInMonth() -> [DayData] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: displayMonth),
              let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth)) else {
            return []
        }
        let numDays = range.count
        let firstWeekday = cal.component(.weekday, from: firstOfMonth) - 1

        var days: [DayData] = []
        for _ in 0..<firstWeekday {
            days.append(DayData(number: 0, date: nil, isCurrentMonth: false))
        }
        for day in 1...numDays {
            if let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(DayData(number: day, date: date, isCurrentMonth: true))
            }
        }
        let remaining = (7 - (days.count % 7)) % 7
        for _ in 0..<remaining {
            days.append(DayData(number: 0, date: nil, isCurrentMonth: false))
        }
        return days
    }

    private func distanceKm(for date: Date) -> Double {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return allSessions
            .filter { cal.dateComponents([.year, .month, .day], from: $0.date) == comps }
            .reduce(0) { $0 + $1.distanceKm }
    }

    private func intensityColor(km: Double) -> Color {
        if km <= 0 { return themeBackground.grayBg }
        let displayKm = km * distanceUnit.conversionFromKm
        if displayKm < 3  { return cAccent.opacity(0.25) }
        if displayKm < 6  { return cAccent.opacity(0.55) }
        return cAccent
    }

    private func textColorForIntensity(km: Double) -> Color {
        if km <= 0 { return cText }
        let displayKm = km * distanceUnit.conversionFromKm
        // Low intensity: accent color text is more readable than white on light accent
        if displayKm < 3 { return themeBackground.isDark ? .white.opacity(0.9) : cAccent }
        // Medium & high: white always readable on 0.55+ opacity
        return .white
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        let cal = Calendar.current
        return cal.dateComponents([.year, .month, .day], from: a) ==
               cal.dateComponents([.year, .month, .day], from: b)
    }

    private func isToday(_ date: Date) -> Bool {
        isSameDay(date, Date())
    }

    private func focusLastWorkoutOfMonth() {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: displayMonth)
        let inMonth = allSessions.filter { cal.dateComponents([.year, .month], from: $0.date) == comps }
        selectedDate = inMonth.max(by: { $0.date < $1.date })?.date ?? displayMonth
    }

    private var sessionsForSelectedDate: [RunSession] {
        allSessions.filter { isSameDay($0.date, selectedDate) }.sorted { $0.date > $1.date }
    }

    private func currentStreak() -> Int { streakFromSessions(allSessions) }

    private func monthYearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = appLanguage.locale
        f.dateFormat = t(.monthYearDateFormat)
        return f.string(from: date)
    }

    private func weekdayLabels() -> [String] {
        let cal = Calendar.current
        let symbols = cal.shortWeekdaySymbols
        return symbols.map { String($0.prefix(1)).uppercased() }
    }

    private func previousMonth() {
        let cal = Calendar.current
        if let d = cal.date(byAdding: .month, value: -1, to: displayMonth) { displayMonth = d }
    }

    private func nextMonth() {
        let cal = Calendar.current
        if let d = cal.date(byAdding: .month, value: 1, to: displayMonth) { displayMonth = d }
    }

    private func canGoToNextMonth() -> Bool {
        let cal = Calendar.current
        let now = Date()
        let d = cal.dateComponents([.year, .month], from: displayMonth)
        let n = cal.dateComponents([.year, .month], from: now)
        return (d.year! < n.year!) || (d.year! == n.year! && d.month! < n.month!)
    }
}

struct DayData: Identifiable {
    let id = UUID()
    let number: Int
    let date: Date?
    let isCurrentMonth: Bool
}
