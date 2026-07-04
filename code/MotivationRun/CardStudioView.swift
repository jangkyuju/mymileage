//
//  CardStudioView.swift
//  MotivationRun
//
//  Full-screen card editor: preview, format toggle, share.
//  Presented as .fullScreenCover from ShareTabView.
//

import SwiftUI
import UIKit

struct CardStudioView: View {
    let template: ShareCardTemplate
    let data: ShareCardData

    @State private var selectedFormat: ShareCardFormat = .story
    @State private var isSharing: Bool = false
    @State private var shareError: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "#0B0D12").ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#6B768C"))
                            .padding(10)
                            .background(Color(hex: "#1B2029"))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(template.label)
                        .font(.pretendard(.semiBold, size: 16))
                        .foregroundColor(Color(hex: "#F2F3F5"))

                    Spacer()

                    // Placeholder to balance HStack
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Card preview
                Spacer()
                cardPreview
                Spacer()

                // Format toggle
                formatToggle
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // Share button
                shareButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Share Failed", isPresented: $shareError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to open the share sheet. Please try again.")
        }
    }

    // MARK: - Card preview

    private var cardPreview: some View {
        GeometryReader { geo in
            let maxH = geo.size.height - 16
            let maxW = geo.size.width  - 32

            let cardNativeW = selectedFormat.size.width
            let cardNativeH = selectedFormat.size.height
            let scaleByW    = maxW / cardNativeW
            let scaleByH    = maxH / cardNativeH
            let scale       = min(scaleByW, scaleByH)
            let displayW    = cardNativeW * scale
            let displayH    = cardNativeH * scale

            ZStack {
                ShareCardView(data: data, template: template, format: selectedFormat)
                    .frame(width: cardNativeW, height: cardNativeH)
                    .scaleEffect(scale)
                    .frame(width: displayW, height: displayH)
                    .clipShape(RoundedRectangle(cornerRadius: 16 * scale))
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(selectedFormat.rawValue)
        }
    }

    // MARK: - Format toggle

    private var formatToggle: some View {
        HStack(spacing: 4) {
            ForEach(ShareCardFormat.allCases, id: \.rawValue) { fmt in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedFormat = fmt }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: fmt.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(fmt.label)
                            .font(.pretendard(.medium, size: 13))
                    }
                    .foregroundColor(selectedFormat == fmt ? Color(hex: "#0B0D12") : Color(hex: "#6B768C"))
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedFormat == fmt ? Color(hex: "#F5C800") : Color(hex: "#1B2029"))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Share button

    private var shareButton: some View {
        Button {
            shareImage()
        } label: {
            HStack(spacing: 8) {
                if isSharing {
                    ProgressView().tint(.black)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Share")
                        .font(.pretendard(.bold, size: 16))
                }
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "#F5C800"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isSharing)
    }

    // MARK: - Share action

    private func shareImage() {
        guard !isSharing else { return }
        isSharing = true
        Task { @MainActor in
            guard let image = ShareCardRenderer.render(data: data, template: template, format: selectedFormat) else {
                isSharing = false
                return
            }
            let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let root = (scene.keyWindow ?? scene.windows.first)?.rootViewController {
                var presenter = root
                while let p = presenter.presentedViewController { presenter = p }
                av.completionWithItemsHandler = { _, _, _, _ in isSharing = false }
                presenter.present(av, animated: true)
            } else {
                isSharing = false
                shareError = true
            }
        }
    }
}
