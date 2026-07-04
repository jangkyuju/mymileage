//
//  CelebrationView.swift
//  MotivationRun
//
//  Full-screen overlay shown when the user hits their monthly goal.
//

import SwiftUI

struct CelebrationView: View {
    let primaryValue: Double
    let primaryUnit: String
    let monthLabel: String
    let goalTarget: Double
    let sessionCount: Int
    let streak: Int
    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var animateIn: Bool = false

    private let confettiColors: [Color] = [
        Color(hex: "#F5A623"), .white, Color(hex: "#888888"),
        Color(hex: "#F5A623"), .white, Color(hex: "#aaaaaa"), Color(hex: "#F5A623")
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0a0a0a"), Color(hex: "#111111")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 56)

                // Confetti dots row
                HStack(spacing: 8) {
                    ForEach(confettiColors.indices, id: \.self) { i in
                        Circle()
                            .fill(confettiColors[i])
                            .frame(width: 6, height: 6)
                            .opacity(animateIn ? 0.7 : 0)
                            .scaleEffect(animateIn ? 1 : 0.3)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(i) * 0.05), value: animateIn)
                    }
                }

                Spacer()

                // Main content
                VStack(spacing: 4) {
                    Text("MONTHLY GOAL REACHED")
                        .font(.pretendard(.semiBold, size: 11))
                        .foregroundColor(Color(hex: "#555555"))
                        .tracking(3)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: animateIn)

                    Spacer().frame(height: 16)

                    Text(primaryValue.cardCelebrationFormatted)
                        .font(.pretendard(.extraBold, size: 86))
                        .foregroundColor(.white)
                        .tracking(-4)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .scaleEffect(animateIn ? 1 : 0.8)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: animateIn)

                    Text("\(primaryUnit) in \(monthLabel)")
                        .font(.pretendard(.regular, size: 20))
                        .foregroundColor(Color(hex: "#555555"))
                        .tracking(1)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.25), value: animateIn)

                    Spacer().frame(height: 20)

                    Text(goalSubtext)
                        .font(.pretendard(.regular, size: 14))
                        .foregroundColor(Color(hex: "#555555"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: animateIn)
                }

                Spacer()

                // Stats chips
                HStack(spacing: 10) {
                    ForEach(chips, id: \.0) { chip in
                        chipView(chip)
                    }
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.4), value: animateIn)

                Spacer().frame(height: 32)

                Button {
                    dismiss()
                    onDismiss?()
                } label: {
                    Text("Close")
                        .font(.pretendard(.medium, size: 14))
                        .foregroundColor(Color(hex: "#333333"))
                }
                .buttonStyle(.plain)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.45), value: animateIn)

                Spacer().frame(height: 48)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            animateIn = true
        }
    }

    // MARK: - Helpers

    private var goalSubtext: String {
        let over = primaryValue - goalTarget
        if over > 0 {
            return "Goal was \(goalTarget.cardCelebrationFormatted) \(primaryUnit).\nYou ran \(over.cardFormatted) over."
        }
        return "Goal was \(goalTarget.cardCelebrationFormatted) \(primaryUnit). You did it."
    }

    private var chips: [(String, String)] {
        var result: [(String, String)] = []
        result.append(("\(sessionCount)", "runs"))
        result.append(("\(streak)", "day streak"))
        let over = primaryValue - goalTarget
        if over > 0 {
            result.append(("+\(over.cardFormatted)", primaryUnit + " over"))
        }
        return result
    }

    private func chipView(_ chip: (String, String)) -> some View {
        HStack(spacing: 4) {
            Text(chip.0).font(.pretendard(.bold, size: 14)).foregroundColor(.white)
            Text(chip.1).font(.pretendard(.regular, size: 14)).foregroundColor(Color(hex: "#888888"))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color(hex: "#1a1a1a"))
        .clipShape(Capsule())
    }
}

private extension Double {
    var cardCelebrationFormatted: String {
        truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(self))" : String(format: "%.1f", self)
    }
    var cardFormatted: String {
        if self >= 100 || truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(rounded()))" }
        return String(format: "%.1f", self)
    }
}
