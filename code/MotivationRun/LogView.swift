//
//  LogView.swift
//  MotivationRun
//

import SwiftUI

// MARK: - 월별 그룹

struct MonthGroup: Identifiable {
    let id: String           // "2025-02" (정렬용)
    let yearMonth: String    // "2025년 2월" (표시용)
    let sessions: [RunSession]  // 날짜 내림차순 정렬
}

// MARK: - 러닝 로그 뷰

struct LogView: View {
    let themeAccent: ThemeAccent
    let themeBackground: ThemeBackground
    let distanceUnit: DistanceUnit
    let appLanguage: AppLanguage
    var tabBarHeight: CGFloat = 88

    @State private var monthGroups: [MonthGroup] = []
    @State private var isLoading = false

    private func t(_ key: LK) -> String { L(key, appLanguage) }
    private var cAccent: Color  { themeBackground.isDark ? themeAccent.colorDark : themeAccent.color }
    private var cBg:     Color  { themeBackground.appBg }
    private var cCard:   Color  { themeBackground.cardBg }
    private var cGray:   Color  { themeBackground.grayBg }
    private var cText:   Color  { themeBackground.mainText }
    private var cSub:    Color  { themeBackground.subText }

    var body: some View {
        NavigationStack {
            ZStack {
                cBg.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(cAccent)
                } else if monthGroups.isEmpty {
                    Text(t(.noRunsMsg))
                        .font(.system(size: 15))
                        .foregroundColor(cSub)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(monthGroups) { group in
                                Text(group.yearMonth)
                                    .font(.pretendard(.semiBold, size: 12))
                                    .foregroundColor(cSub)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 20)
                                    .padding(.bottom, 8)

                                ForEach(Array(group.sessions.enumerated()), id: \.element.id) { index, session in
                                    NavigationLink {
                                        RunSessionDetailView(
                                            session: session,
                                            runNumber: group.sessions.count - index,
                                            distanceUnit: distanceUnit,
                                            appLanguage: appLanguage,
                                            themeAccent: themeAccent,
                                            themeBackground: themeBackground
                                        )
                                    } label: {
                                        RunSessionCard(
                                            session: session,
                                            runNumber: group.sessions.count - index,
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
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                                }
                            }

                            Color.clear.frame(height: tabBarHeight + 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .background(cBg)
                }
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(themeBackground.colorScheme)
            .onAppear { fetchSessions() }
        }
    }

    private func fetchSessions() {
        guard !isLoading else { return }
        isLoading = true
        HealthKitService.shared.fetchAllRunningSessions { sessions in
            monthGroups = groupByMonth(sessions: sessions)
            isLoading = false
        }
    }

    private func groupByMonth(sessions: [RunSession]) -> [MonthGroup] {
        let cal = Calendar.current
        let fmt: DateFormatter = {
            let f = DateFormatter()
            f.locale = appLanguage.locale
            f.dateFormat = t(.monthYearDateFormat)
            return f
        }()

        var dict: [String: [RunSession]] = [:]
        for session in sessions {
            let comps = cal.dateComponents([.year, .month], from: session.date)
            let key = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
            dict[key, default: []].append(session)
        }

        return dict.keys.sorted(by: >).map { key in
            let groupSessions = (dict[key] ?? []).sorted { $0.date > $1.date }
            let displayDate = groupSessions.first?.date ?? Date()
            return MonthGroup(
                id: key,
                yearMonth: fmt.string(from: displayDate),
                sessions: groupSessions
            )
        }
    }
}

// MARK: - 러닝 세션 카드 (2행 레이아웃)

struct RunSessionCard: View {
    let session: RunSession
    let runNumber: Int
    let distanceUnit: DistanceUnit
    let language: AppLanguage
    let themeBackground: ThemeBackground
    let cAccent: Color
    let cCard: Color
    let cText: Color
    let cSub: Color

    private var distance: Double { session.distanceKm * distanceUnit.conversionFromKm }

    private var distanceStr: String { String(format: "%.2f", distance) }

    private var durationStr: String {
        let total = Int(session.durationMinutes)
        let h = total / 60
        let m = total % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private var caloriesStr: String {
        session.calories > 0 ? String(format: "%.0f", session.calories) : "-"
    }

    private var paceStr: String {
        guard distance > 0 else { return "-" }
        let pacePerUnit = session.durationMinutes / distance
        let totalSec = Int(pacePerUnit * 60)
        let m = totalSec / 60
        let s = totalSec % 60
        return "\(m)'\(String(format: "%02d", s))\""
    }

    private var dayStr: String {
        let f = DateFormatter()
        f.locale = language.locale
        f.dateFormat = "d"
        return f.string(from: session.date)
    }

    private var weekdayMonthStr: String {
        let f = DateFormatter()
        f.locale = language.locale
        f.dateFormat = "EEE, MMM"
        return f.string(from: session.date)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ─── Row 1: badge · day · weekday+month · distance ───
            HStack(alignment: .center, spacing: 10) {
                // Number badge
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(cAccent.opacity(themeBackground.isDark ? 0.2 : 0.12))
                        .frame(width: 32, height: 32)
                    Text("#\(runNumber)")
                        .font(.pretendard(.bold, size: 10))
                        .foregroundColor(cAccent)
                }

                // Day + weekday/month
                VStack(alignment: .leading, spacing: 1) {
                    Text(dayStr)
                        .font(.pretendard(.bold, size: 18))
                        .foregroundColor(cText)
                        .lineLimit(1)
                    Text(weekdayMonthStr)
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(cSub)
                        .lineLimit(1)
                }

                Spacer()

                // Distance (right-aligned, prominent)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(distanceStr)
                        .font(.pretendard(.bold, size: 22))
                        .foregroundColor(cText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(distanceUnit.symbol)
                        .font(.pretendard(.semiBold, size: 11))
                        .foregroundColor(cSub)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Divider
            Rectangle()
                .fill(themeBackground.lineColor)
                .frame(height: 1)
                .padding(.horizontal, 14)

            // ─── Row 2: pace · time · calories ───
            HStack(spacing: 0) {
                bottomStat(value: paceStr,     unit: "/\(distanceUnit.symbol)", label: L(.dashboardAvgPace, language))
                statDivider
                bottomStat(value: durationStr, unit: "",                         label: L(.columnTime, language))
                statDivider
                bottomStat(value: caloriesStr, unit: "kcal",                     label: L(.dashboardTotalCalories, language))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            themeBackground.isDark ? Color.white.opacity(0.05) : Color(hex: "#0D1220").opacity(0.04),
                            lineWidth: 1
                        )
                )
        )
    }

    private var statDivider: some View {
        Rectangle()
            .fill(themeBackground.lineColor)
            .frame(width: 1, height: 22)
            .padding(.horizontal, 10)
    }

    private func bottomStat(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.pretendard(.semiBold, size: 14))
                    .foregroundColor(cText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.pretendard(.medium, size: 10))
                        .foregroundColor(cSub)
                }
            }
            Text(label)
                .font(.pretendard(.medium, size: 10))
                .foregroundColor(cSub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
