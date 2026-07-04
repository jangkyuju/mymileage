//
//  OnboardingView.swift
//  MotivationRun
//
//  온보딩: Welcome → Survey ×4 → Suggestion → Done → Health(마지막, 스킵 불가)
//  완료 시 선택한 목표와 빈도를 SharedDataManager에 저장.
//

import SwiftUI

// MARK: - Private survey types

private enum MonthlyBucket: CaseIterable, Equatable {
    case rarely, under30, under60, under100, over100
    var baseKm: Double {
        switch self {
        case .rarely:   return 5
        case .under30:  return 25
        case .under60:  return 50
        case .under100: return 85
        case .over100:  return 120
        }
    }
    func label(_ t: (LK) -> String) -> String {
        switch self {
        case .rarely:   return t(.onbQ1Rarely)
        case .under30:  return t(.onbQ1Under30)
        case .under60:  return t(.onbQ1Under60)
        case .under100: return t(.onbQ1Under100)
        case .over100:  return t(.onbQ1Over100)
        }
    }
    var icon: String { "figure.run" }
}

private enum SessionBucket: CaseIterable, Equatable {
    case under3, under5, under10, under20, over20
    var km: Double {
        switch self {
        case .under3:  return 2
        case .under5:  return 4
        case .under10: return 7.5
        case .under20: return 15
        case .over20:  return 25
        }
    }
    func label(_ t: (LK) -> String) -> String {
        switch self {
        case .under3:  return t(.onbQ2Under3)
        case .under5:  return t(.onbQ2Under5)
        case .under10: return t(.onbQ2Under10)
        case .under20: return t(.onbQ2Under20)
        case .over20:  return t(.onbQ2Over20)
        }
    }
    var icon: String { "ruler" }
}

private enum FrequencyChoice: CaseIterable, Equatable {
    case daily, threeToFour, oneToTwo, occasionally
    var runFrequency: RunFrequency {
        switch self {
        case .daily:        return .daily
        case .threeToFour:  return .everyOther
        case .oneToTwo, .occasionally: return .every3Days
        }
    }
    func label(_ t: (LK) -> String) -> String {
        switch self {
        case .daily:        return t(.onbQ3Daily)
        case .threeToFour:  return t(.onbQ3ThreeToFour)
        case .oneToTwo:     return t(.onbQ3OneToTwo)
        case .occasionally: return t(.onbQ3Rarely)
        }
    }
    var icon: String {
        switch self {
        case .daily:        return "calendar.badge.checkmark"
        case .threeToFour:  return "calendar"
        case .oneToTwo:     return "calendar.badge.minus"
        case .occasionally: return "clock"
        }
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @Binding var language: AppLanguage
    let cAccent: Color
    let cBg: Color
    let cCard: Color
    let cText: Color
    let cSub: Color
    let onFinish: () -> Void

    @State private var currentPage = 0

    // Survey state
    @State private var monthlyBucket: MonthlyBucket = .under30
    @State private var sessionBucket: SessionBucket = .under5
    @State private var frequencyChoice: FrequencyChoice = .oneToTwo
    @State private var goalTypeChoice: GoalType = .distance
    @State private var suggestedGoal: Double = 35.0

    private let pageCount = 10
    private let firstLockedPage = 7   // Health 권한 연동 페이지부터 skip 불가

    private func t(_ key: LK) -> String { L(key, language) }

    var body: some View {
        ZStack {
            cBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top — skip jumps to the Health page; Health onward is not skippable
                HStack {
                    Spacer()
                    if currentPage < firstLockedPage {
                        Button {
                            if currentPage < 6 { suggestedGoal = computeSuggestedGoal() }
                            saveGoalData()
                            withAnimation { currentPage = firstLockedPage }
                        } label: {
                            Text(t(.onbSkip))
                                .font(.pretendard(.medium, size: 15))
                                .foregroundColor(cSub)
                        }
                    }
                }
                .frame(height: 24)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Page content
                // Page order: Welcome(0) Language(1) Q1(2) Q2(3) Q3(4) GoalType(5) Suggestion(6) Health(7) DataSource(8) Done(9)
                // Health(7) 부터는 skip 불가 (firstLockedPage)
                TabView(selection: $currentPage) {
                    page(icon: "figure.run",
                         title: t(.onbWelcomeTitle),
                         body: t(.onbWelcomeBody))
                        .tag(0)

                    // Language selection
                    languagePage
                        .tag(1)

                    // Q1 — monthly average km
                    surveyPage(
                        icon: "chart.bar.xaxis",
                        question: t(.onbQ1Title),
                        options: MonthlyBucket.allCases.map { ($0.label(t), $0.icon) },
                        selectedIndex: MonthlyBucket.allCases.firstIndex(of: monthlyBucket) ?? 1,
                        onSelect: { monthlyBucket = MonthlyBucket.allCases[$0] }
                    )
                    .tag(2)

                    // Q2 — typical session distance
                    surveyPage(
                        icon: "arrow.right.to.line.alt",
                        question: t(.onbQ2Title),
                        options: SessionBucket.allCases.map { ($0.label(t), $0.icon) },
                        selectedIndex: SessionBucket.allCases.firstIndex(of: sessionBucket) ?? 1,
                        onSelect: { sessionBucket = SessionBucket.allCases[$0] }
                    )
                    .tag(3)

                    // Q3 — frequency
                    surveyPage(
                        icon: "calendar",
                        question: t(.onbQ3Title),
                        options: FrequencyChoice.allCases.map { ($0.label(t), $0.icon) },
                        selectedIndex: FrequencyChoice.allCases.firstIndex(of: frequencyChoice) ?? 2,
                        onSelect: { frequencyChoice = FrequencyChoice.allCases[$0] }
                    )
                    .tag(4)

                    // Q4 — goal type
                    goalTypeSurveyPage
                        .tag(5)

                    // Goal suggestion
                    goalSuggestionPage
                        .tag(6)

                    // Health 권한 연동 — non-skippable
                    healthPage
                        .tag(7)

                    // Data source 설명 — non-skippable
                    dataSourcePage
                        .tag(8)

                    // 준비 완료 — 마지막 페이지
                    page(icon: "checkmark.seal.fill",
                         title: t(.onbDoneTitle),
                         body: t(.onbDoneBody))
                        .tag(9)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pageCount, id: \.self) { idx in
                        Capsule()
                            .fill(idx == currentPage ? cAccent : cSub.opacity(0.3))
                            .frame(width: idx == currentPage ? 22 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 24)

                // Bottom button
                Button(action: advance) {
                    Text(currentPage == pageCount - 1 ? t(.onbStart) : t(.onbNext))
                        .font(.pretendard(.bold, size: 17))
                        .foregroundColor(cBg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(cAccent)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(cBg.isDarkColor ? .dark : .light)
    }

    // MARK: - Static pages

    private func page(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            iconBadge(icon)
            Text(title)
                .font(.pretendard(.extraBold, size: 26))
                .foregroundColor(cText)
                .multilineTextAlignment(.center)
            Text(body)
                .font(.pretendard(.regular, size: 16))
                .foregroundColor(cSub)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // Health page: guide text (yellow) above mock, body text below
    private var healthPage: some View {
        VStack(spacing: 16) {
            Spacer()
            iconBadge("heart.text.square", tint: .red)
            Text(t(.onbHealthTitle))
                .font(.pretendard(.extraBold, size: 26))
                .foregroundColor(cText)
                .multilineTextAlignment(.center)
            Text(t(.onbHealthGuide))
                .font(.pretendard(.medium, size: 14))
                .foregroundColor(cAccent)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 12)
            permissionMock
                .padding(.top, 2)
            Text(t(.onbHealthBody))
                .font(.pretendard(.regular, size: 15))
                .foregroundColor(cSub)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // Data source page: guide (yellow) above source list mock, body below
    private var dataSourcePage: some View {
        VStack(spacing: 16) {
            Spacer()
            iconBadge("dot.radiowaves.left.and.right")
            Text(t(.onbSourceTitle))
                .font(.pretendard(.extraBold, size: 26))
                .foregroundColor(cText)
                .multilineTextAlignment(.center)
            Text(t(.onbSourceGuide))
                .font(.pretendard(.medium, size: 14))
                .foregroundColor(cAccent)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 12)
            sourceMock
                .padding(.top, 2)
            Text(t(.onbSourceBody))
                .font(.pretendard(.regular, size: 15))
                .foregroundColor(cSub)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Survey page (generic)

    private func surveyPage(
        icon: String,
        question: String,
        options: [(String, String)],
        selectedIndex: Int,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                iconBadge(icon)
                Text(question)
                    .font(.pretendard(.extraBold, size: 22))
                    .foregroundColor(cText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)
            }

            Spacer().frame(height: 24)

            VStack(spacing: 10) {
                ForEach(options.indices, id: \.self) { idx in
                    let (label, optIcon) = options[idx]
                    surveyChoiceCard(
                        label: label,
                        icon: optIcon,
                        isSelected: idx == selectedIndex
                    ) { onSelect(idx) }
                }
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func surveyChoiceCard(
        label: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? cBg : cAccent)
                    .frame(width: 22)
                Text(label)
                    .font(.pretendard(.semiBold, size: 16))
                    .foregroundColor(isSelected ? cBg : cText)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(cBg)
                } else {
                    Circle()
                        .stroke(cSub.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(isSelected ? cAccent : cCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? cAccent : cSub.opacity(0.15), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Language selection page

    private var languagePage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                iconBadge("globe")
                Text(t(.onbLanguageTitle))
                    .font(.pretendard(.extraBold, size: 22))
                    .foregroundColor(cText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)
            }

            Spacer().frame(height: 24)

            VStack(spacing: 10) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    surveyChoiceCard(
                        label: lang.displayName,
                        icon: "globe",
                        isSelected: lang == language
                    ) {
                        language = lang
                        SharedDataManager.shared.saveLanguage(lang)
                    }
                }
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Goal type survey page

    private var goalTypeSurveyPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                iconBadge("target")
                Text(t(.onbGoalTypeQ))
                    .font(.pretendard(.extraBold, size: 22))
                    .foregroundColor(cText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)
            }

            Spacer().frame(height: 24)

            VStack(spacing: 10) {
                goalTypeCard(.distance,
                             label: t(.goalTypeDistance),
                             icon: "figure.run",
                             detail: "km / mi")
                goalTypeCard(.calories,
                             label: t(.goalTypeCalories),
                             icon: "flame.fill",
                             detail: "kcal")
                goalTypeCard(.duration,
                             label: t(.goalTypeDuration),
                             icon: "clock.fill",
                             detail: "hr")
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func goalTypeCard(_ type: GoalType, label: String, icon: String, detail: String) -> some View {
        let isSelected = goalTypeChoice == type
        return Button { goalTypeChoice = type } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? cBg : cAccent)
                    .frame(width: 22)
                Text(label)
                    .font(.pretendard(.semiBold, size: 16))
                    .foregroundColor(isSelected ? cBg : cText)
                Spacer()
                Text(detail)
                    .font(.pretendard(.regular, size: 13))
                    .foregroundColor(isSelected ? cBg.opacity(0.7) : cSub)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(cBg)
                        .padding(.leading, 4)
                } else {
                    Circle()
                        .stroke(cSub.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(isSelected ? cAccent : cCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? cAccent : cSub.opacity(0.15), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Goal suggestion page

    private var goalSuggestionPage: some View {
        VStack(spacing: 0) {
            Spacer()

            iconBadge("star.fill")

            Spacer().frame(height: 16)

            Text(t(.onbSuggestionTitle))
                .font(.pretendard(.extraBold, size: 24))
                .foregroundColor(cText)

            Spacer().frame(height: 6)

            Text(t(.onbSuggestionBody))
                .font(.pretendard(.regular, size: 15))
                .foregroundColor(cSub)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 36)

            // Big goal number
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(formattedGoalValue)
                    .font(.pretendard(.extraBold, size: 80))
                    .foregroundColor(cAccent)
                    .tracking(-3)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(goalUnit)
                    .font(.pretendard(.semiBold, size: 22))
                    .foregroundColor(cSub)
            }

            Spacer().frame(height: 24)

            // Slider
            Slider(value: $suggestedGoal,
                   in: sliderRange,
                   step: sliderStep)
                .tint(cAccent)
                .padding(.horizontal, 8)

            Text(t(.onbSuggestionAdjust))
                .font(.pretendard(.regular, size: 13))
                .foregroundColor(cSub)
                .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .onAppear { suggestedGoal = computeSuggestedGoal() }
    }

    // MARK: - Goal helpers

    private var goalUnit: String {
        switch goalTypeChoice {
        case .distance: return "km"
        case .calories: return "kcal"
        case .duration: return "hr"
        }
    }

    private var sliderRange: ClosedRange<Double> {
        switch goalTypeChoice {
        case .distance: return 10...300
        case .calories: return 500...30000
        case .duration: return 1...50
        }
    }

    private var sliderStep: Double {
        switch goalTypeChoice {
        case .distance: return 5
        case .calories: return 500
        case .duration: return 0.5
        }
    }

    private var formattedGoalValue: String {
        switch goalTypeChoice {
        case .distance: return "\(Int(suggestedGoal))"
        case .calories: return "\(Int(suggestedGoal))"
        case .duration:
            if suggestedGoal.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(suggestedGoal))"
            }
            return String(format: "%.1f", suggestedGoal)
        }
    }

    // Factor always ≥ 1.1: suggested goal is always above stated monthly average.
    // Longer single sessions → higher factor (more ambitious stretch).
    private func computeSuggestedGoal() -> Double {
        let baseKm = monthlyBucket.baseKm
        let sessionKm = sessionBucket.km
        let factor: Double = sessionKm < 5  ? 1.1
                           : sessionKm < 10 ? 1.2
                           : sessionKm < 20 ? 1.35
                           : 1.5
        let raw = baseKm * factor
        let roundedKm = max(10, (raw / 5).rounded() * 5)
        switch goalTypeChoice {
        case .distance: return roundedKm
        case .calories: return max(500, (roundedKm * 65 / 500).rounded() * 500)
        case .duration: return max(1, (roundedKm / 8 / 0.5).rounded() * 0.5)
        }
    }

    // MARK: - Navigation

    private func advance() {
        if currentPage < pageCount - 1 {
            if currentPage == 5 {
                suggestedGoal = computeSuggestedGoal()
            } else if currentPage == 6 {
                saveGoalData()
            }
            withAnimation { currentPage += 1 }
        } else {
            onFinish()
        }
    }

    private func saveGoalData() {
        SharedDataManager.shared.saveGoal(type: goalTypeChoice, target: suggestedGoal)
        SharedDataManager.shared.saveRunFrequency(frequencyChoice.runFrequency)
    }

    // MARK: - Health page helpers

    private var permissionMock: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.red)
                    .frame(width: 22)
                Text(t(.onbHealthAllowAll))
                    .font(.pretendard(.semiBold, size: 14))
                    .foregroundColor(cAccent)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            mockDivider
            mockRow(icon: "figure.run", color: .orange)
            mockDivider
            mockRow(icon: "heart.fill", color: .red)
            mockDivider
            mockRow(icon: "flame.fill", color: .orange)
        }
        .background(cCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cSub.opacity(0.15), lineWidth: 1)
        )
        .frame(maxWidth: 280)
    }

    private var mockDivider: some View {
        Rectangle().fill(cSub.opacity(0.15)).frame(height: 1)
    }

    // MARK: - Data source page helpers

    // "모든 소스"를 선택된 상태로 보여주고, 개별 소스도 고를 수 있음을 시각화
    private var sourceMock: some View {
        VStack(spacing: 0) {
            sourceRow(icon: "square.stack.3d.up.fill", color: cAccent,
                      name: t(.onbSourceAllLabel), selected: true)
            mockDivider
            sourceRow(icon: "location.fill", color: Color(hex: "#007CC3"),
                      name: "Garmin Connect", selected: false)
            mockDivider
            sourceRow(icon: "applewatch", color: cText,
                      name: "Apple Watch", selected: false)
            mockDivider
            sourceRow(icon: "figure.run", color: Color(hex: "#FF6B00"),
                      name: "Nike Run Club", selected: false)
            mockDivider
            sourceRow(icon: "flame.fill", color: Color(hex: "#FC4C02"),
                      name: "Strava", selected: false)
        }
        .background(cCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cSub.opacity(0.15), lineWidth: 1)
        )
        .frame(maxWidth: 280)
    }

    private func sourceRow(icon: String, color: Color, name: String, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(color)
                .frame(width: 22)
            Text(name)
                .font(.pretendard(.semiBold, size: 14))
                .foregroundColor(selected ? cAccent : cText)
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(selected ? cAccent : cSub.opacity(0.35))
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func mockRow(icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 22)
            RoundedRectangle(cornerRadius: 3)
                .fill(cSub.opacity(0.25))
                .frame(width: 72, height: 8)
            Spacer()
            Capsule()
                .fill(Color.green)
                .frame(width: 34, height: 20)
                .overlay(alignment: .trailing) {
                    Circle().fill(.white).frame(width: 16, height: 16).padding(2)
                }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func iconBadge(_ icon: String, tint: Color? = nil) -> some View {
        ZStack {
            Circle()
                .fill((tint ?? cAccent).opacity(0.14))
                .frame(width: 96, height: 96)
            Image(systemName: icon)
                .font(.system(size: 42, weight: .semibold))
                .foregroundColor(tint ?? cAccent)
        }
    }
}

// MARK: - Color helper

private extension Color {
    var isDarkColor: Bool {
        guard let comps = UIColor(self).cgColor.components, comps.count >= 3 else { return true }
        let luminance = 0.299 * comps[0] + 0.587 * comps[1] + 0.114 * comps[2]
        return luminance < 0.5
    }
}
