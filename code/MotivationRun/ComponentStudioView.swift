//
//  ComponentStudioView.swift
//  MotivationRun
//
//  Full-screen preview + Download / Share for individual stat components.
//

import SwiftUI
import Photos

struct ComponentStudioView: View {
    let component: ShareComponent
    let data: ShareCardData
    let isPro: Bool
    var onDismiss: () -> Void

    @State private var shareError: Bool = false
    @State private var saveSuccess: Bool = false

    var body: some View {
        ZStack {
            Color(hex: "#111111").ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(10)
                    }
                    Spacer()
                    Text(component.label)
                        .font(.pretendard(.semiBold, size: 16))
                        .foregroundColor(.white)
                    Spacer()
                    // balance button
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 8)

                Spacer()

                // Component preview
                Group {
                    switch component {
                    case .numberTile:
                        NumberTileComponent(data: data)
                    case .monthlyBar:
                        proGated { MonthlyBarChartComponent(data: data) }
                    case .cumulativeLine:
                        proGated { CumulativeLineComponent(data: data) }
                    case .streakBadge:
                        StreakBadgeComponent(data: data)
                    case .statsTrio:
                        StatsTrioComponent(data: data)
                    }
                }
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                .padding(.horizontal, 20)

                Spacer()

                // Description
                Text(component.description)
                    .font(.pretendard(.regular, size: 14))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)

                // Action buttons
                if component.isPro && !isPro {
                    proLockedButton
                } else {
                    actionButtons
                }

                Spacer().frame(height: 36)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Share Failed", isPresented: $shareError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to open the share sheet. Please try again.")
        }
        .overlay(
            Group {
                if saveSuccess {
                    VStack {
                        Spacer()
                        Text("Saved to Photos")
                            .font(.pretendard(.semiBold, size: 14))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .padding(.bottom, 80)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        )
    }

    @ViewBuilder
    private func proGated<V: View>(_ content: () -> V) -> some View {
        if isPro {
            content()
        } else {
            content().blur(radius: 8)
        }
    }

    private var proLockedButton: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                Text("MotivationRun Pro")
                    .font(.pretendard(.semiBold, size: 14))
            }
            .foregroundColor(data.accentColor)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(data.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: saveToPhotos) {
                Label("Save", systemImage: "arrow.down.to.line")
                    .font(.pretendard(.semiBold, size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Button(action: shareImage) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.pretendard(.bold, size: 15))
                    .foregroundColor(Color(hex: "#111111"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(data.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    @MainActor
    private func renderImage() -> UIImage? {
        renderComponent(component, data: data)
    }

    private func saveToPhotos() {
        Task { @MainActor in
            guard let image = renderImage() else { shareError = true; return }
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else { return }
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                DispatchQueue.main.async {
                    withAnimation { saveSuccess = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { saveSuccess = false }
                    }
                }
            }
        }
    }

    private func shareImage() {
        Task { @MainActor in
            guard let image = renderImage() else { shareError = true; return }
            let scenes = UIApplication.shared.connectedScenes
            guard let windowScene = scenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                shareError = true
                return
            }
            let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            av.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(av, animated: true)
        }
    }
}
