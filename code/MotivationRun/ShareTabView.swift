//
//  ShareTabView.swift
//  MotivationRun
//
//  Dedicated Share tab: Templates gallery + Components section, same scrollview.
//

import SwiftUI

struct ShareTabView: View {
    let data: ShareCardData
    let isPro: Bool
    let themeBackground: ThemeBackground

    @State private var selectedCategory: ShareCardCategory = .all
    @State private var studioTemplate: ShareCardTemplate? = nil
    @State private var studioComponent: ShareComponent? = nil
    @State private var showProAlert: Bool = false
    @State private var lockedTemplate: ShareCardTemplate? = nil

    private var cBg:    Color { themeBackground.appBg }
    private var cCard:  Color { themeBackground.cardBg }
    private var cText:  Color { themeBackground.mainText }
    private var cSub:   Color { themeBackground.subText }
    private var cGray:  Color { themeBackground.grayBg }

    private var filteredTemplates: [ShareCardTemplate] {
        guard selectedCategory != .all else { return ShareCardTemplate.allCases }
        return ShareCardTemplate.allCases.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationView {
            ZStack {
                cBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // ── Templates ──
                        sectionHeader("Templates")
                            .padding(.top, 8)

                        categoryFilter
                            .padding(.top, 8)

                        templateGrid
                            .padding(.top, 16)

                        // ── Components ──
                        sectionHeader("Components")
                            .padding(.top, 28)

                        Text("Export individual stat visuals as transparent or dark PNG")
                            .font(.pretendard(.regular, size: 13))
                            .foregroundColor(cSub)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                        componentList
                            .padding(.top, 12)
                            .padding(.bottom, 104) // clear tab bar
                    }
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(themeBackground.colorScheme)
        }
        .fullScreenCover(item: $studioTemplate) { tmpl in
            CardStudioView(template: tmpl, data: data)
        }
        .fullScreenCover(item: $studioComponent) { comp in
            ComponentStudioView(
                component: comp,
                data: data,
                isPro: isPro,
                onDismiss: { studioComponent = nil }
            )
        }
        .alert("Upgrade to Pro", isPresented: $showProAlert) {
            Button("Upgrade") {
                Task { _ = await StoreManager.shared.purchasePro() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This template is exclusive to MotivationRun Pro. Upgrade once to unlock all Pro templates and the lock-screen widget.")
        }
    }

    // MARK: - Category filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShareCardCategory.allCases, id: \.rawValue) { cat in
                    categoryChip(cat)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func categoryChip(_ cat: ShareCardCategory) -> some View {
        let isSelected = selectedCategory == cat
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedCategory = cat }
        } label: {
            Text(cat.rawValue)
                .font(.pretendard(isSelected ? .bold : .medium, size: 13))
                .foregroundColor(isSelected ? Color(hex: "#0B0D12") : cSub)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: "#F5C800") : cCard)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Template grid

    private var templateGrid: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 12
            let hPad: CGFloat    = 16
            let cellW = (geo.size.width - hPad * 2 - spacing) / 2
            let cellH = cellW * (640.0 / 360.0)
            let scale = cellW / 360

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: spacing), GridItem(.flexible())],
                spacing: 20
            ) {
                ForEach(filteredTemplates, id: \.rawValue) { tmpl in
                    templateCell(tmpl, cellW: cellW, cellH: cellH, scale: scale)
                }
            }
            .padding(.horizontal, hPad)
        }
        .frame(height: templateGridHeight)
    }

    private var templateGridHeight: CGFloat {
        let count = filteredTemplates.count
        let rows  = CGFloat((count + 1) / 2)
        let screenW = UIScreen.main.bounds.width
        let cellW   = (screenW - 44) / 2
        let cellH   = cellW * (640.0 / 360.0)
        return rows * (cellH + 46) + (rows - 1) * 20
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.pretendard(.bold, size: 20))
            .foregroundColor(cText)
            .padding(.horizontal, 16)
    }

    // MARK: - Component list

    private var componentList: some View {
        VStack(spacing: 10) {
            ForEach(ShareComponent.allCases) { comp in
                componentRow(comp)
            }
        }
        .padding(.horizontal, 16)
    }

    private func componentRow(_ comp: ShareComponent) -> some View {
        let locked = comp.isPro && !isPro
        return Button {
            studioComponent = comp
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(locked ? cGray : Color(hex: "#F5C800").opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: comp.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(locked ? cSub : Color(hex: "#F5C800"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(comp.label)
                            .font(.pretendard(.semiBold, size: 15))
                            .foregroundColor(cText)
                        if locked {
                            Text("PRO")
                                .font(.pretendard(.bold, size: 10))
                                .foregroundColor(Color(hex: "#F5C800"))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#F5C800").opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    Text(comp.description)
                        .font(.pretendard(.regular, size: 12))
                        .foregroundColor(cSub)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(cSub.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(cCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Template cell

    private func templateCell(_ tmpl: ShareCardTemplate, cellW: CGFloat, cellH: CGFloat, scale: CGFloat) -> some View {
        let locked = tmpl.isPro && !isPro

        return VStack(spacing: 8) {
            ZStack {
                // Card thumbnail
                ShareCardView(data: data, template: tmpl, format: .story)
                    .frame(width: 360, height: 640)
                    .scaleEffect(scale, anchor: .top)
                    .frame(width: cellW, height: cellH)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if locked {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.5))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(width: cellW, height: cellH)

            VStack(spacing: 2) {
                Text(tmpl.label)
                    .font(.pretendard(.semiBold, size: 12))
                    .foregroundColor(cText)
                Text(tmpl.category.rawValue.uppercased())
                    .font(.pretendard(.medium, size: 9))
                    .foregroundColor(cSub)
                    .tracking(1)
            }
        }
        .onTapGesture {
            if locked {
                showProAlert = true
            } else {
                studioTemplate = tmpl
            }
        }
    }
}

// ShareCardTemplate must conform to Identifiable for fullScreenCover(item:)
extension ShareCardTemplate: Identifiable {
    public var id: String { rawValue }
}
