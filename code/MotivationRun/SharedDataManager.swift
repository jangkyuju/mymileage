//
//  SharedDataManager.swift
//  MotivationRun
//
//  ⚠️ 메인 앱 타겟 + 위젯 타겟 양쪽 Target Membership 체크 필수
//

import Foundation
import UIKit
import WidgetKit

class SharedDataManager {
    static let shared = SharedDataManager()
    private init() {}  // [FIX LOW-003] singleton 보호

    private let appGroupID = "group.com.jangkyuju.motivationrun"

    // [FIX HIGH-001] 매 접근마다 재생성 → lazy 한 번만 생성
    private lazy var userDefaults: UserDefaults? = {
        let defaults = UserDefaults(suiteName: appGroupID)
        if defaults == nil {
            print("❌ [SharedDataManager] 앱 그룹 설정 없음: \(appGroupID)")
        }
        return defaults
    }()

    // MARK: - MonthlyStats

    func saveMonthlyStats(_ stats: MonthlyStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        userDefaults?.set(data, forKey: "monthlyStats")
        // [FIX MEDIUM-001] synchronize() 제거 — iOS 12+ 자동 처리
        print("💾 [SharedDataManager] 저장 완료: \(stats.currentValue)\(stats.goalType.unit)")
    }

    func getMonthlyStats() -> MonthlyStats? {
        guard let data = userDefaults?.data(forKey: "monthlyStats") else { return nil }
        return try? JSONDecoder().decode(MonthlyStats.self, from: data)
    }

    // MARK: - Goal (GoalType + Target)

    func saveGoal(type: GoalType, target: Double) {
        userDefaults?.set(type.rawValue, forKey: "goalType")
        userDefaults?.set(target, forKey: "goalTarget")
        // [FIX MEDIUM-001] synchronize() 제거
    }

    func getGoalType() -> GoalType {
        guard let raw = userDefaults?.string(forKey: "goalType"),
              let type = GoalType(rawValue: raw) else { return .distance }
        return type
    }

    func getGoalTarget() -> Double {
        let stored = userDefaults?.double(forKey: "goalTarget") ?? 0
        return stored > 0 ? stored : getGoalType().defaultTarget
    }

    // MARK: - RunFrequency

    func saveRunFrequency(_ frequency: RunFrequency) {
        userDefaults?.set(frequency.rawValue, forKey: "runFrequency")
        // [FIX MEDIUM-001] synchronize() 제거
    }

    func getRunFrequency() -> RunFrequency {
        // [FIX MEDIUM-002] 명시적 키 존재 여부 확인 → nil이면 기본값 .everyOther
        guard userDefaults?.object(forKey: "runFrequency") != nil,
              let raw = userDefaults?.integer(forKey: "runFrequency"),
              let frequency = RunFrequency(rawValue: raw) else {
            return .everyOther
        }
        return frequency
    }

    // MARK: - Theme

    func saveTheme(accent: ThemeAccent, background: ThemeBackground) {
        userDefaults?.set(accent.rawValue, forKey: "themeAccent")
        userDefaults?.set(background.rawValue, forKey: "themeBackground")
    }

    func getThemeAccent() -> ThemeAccent {
        guard let raw = userDefaults?.string(forKey: "themeAccent"),
              let accent = ThemeAccent(rawValue: raw) else { return .blue }
        return accent
    }

    func getThemeBackground() -> ThemeBackground {
        guard let raw = userDefaults?.string(forKey: "themeBackground"),
              let bg = ThemeBackground(rawValue: raw) else { return .white }
        return bg
    }

    // MARK: - DistanceUnit

    func saveDistanceUnit(_ unit: DistanceUnit) {
        userDefaults?.set(unit.rawValue, forKey: "distanceUnit")
    }

    func getDistanceUnit() -> DistanceUnit {
        guard let raw = userDefaults?.string(forKey: "distanceUnit"),
              let unit = DistanceUnit(rawValue: raw) else { return .km }
        return unit
    }

    // MARK: - NotificationSettings

    func saveNotificationSettings(_ settings: NotificationSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults?.set(data, forKey: "notificationSettings")
    }

    func getNotificationSettings() -> NotificationSettings {
        guard let data = userDefaults?.data(forKey: "notificationSettings"),
              let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
            return NotificationSettings()
        }
        return settings
    }

    // MARK: - Language

    func saveLanguage(_ lang: AppLanguage) {
        userDefaults?.set(lang.rawValue, forKey: "appLanguage")
    }

    func getLanguage() -> AppLanguage {
        // 저장된 설정 우선, 없으면 시스템 언어에서 추론
        if let raw = userDefaults?.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: raw) {
            return lang
        }
        let systemCode = Locale.current.language.languageCode?.identifier ?? "en"
        return AppLanguage(rawValue: systemCode) ?? .english
    }

    // MARK: - Widget Design

    func saveWidgetDesign(_ design: WidgetDesign) {
        userDefaults?.set(design.rawValue, forKey: "widgetDesign")
    }

    func getWidgetDesign() -> WidgetDesign {
        guard let raw = userDefaults?.string(forKey: "widgetDesign"),
              let design = WidgetDesign(rawValue: raw) else { return .complete }
        return design
    }

    // MARK: - Pro 상태

    func saveIsPro(_ value: Bool) {
        userDefaults?.set(value, forKey: "isPro")
    }

    func getIsPro() -> Bool {
        userDefaults?.bool(forKey: "isPro") ?? false
    }

    // MARK: - Widget Photo Gallery

    private var galleryDirectoryURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("widget_gallery", isDirectory: true)
    }

    private func galleryImageURL(id: String) -> URL? {
        galleryDirectoryURL?.appendingPathComponent("gallery_\(id).jpg")
    }

    private func ensureGalleryDirectoryExists() {
        guard let dir = galleryDirectoryURL else { return }
        guard !FileManager.default.fileExists(atPath: dir.path) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private var galleryImageIDs: [String] {
        get {
            guard let data = userDefaults?.data(forKey: "galleryImageIDs"),
                  let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return ids
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            userDefaults?.set(data, forKey: "galleryImageIDs")
        }
    }

    var galleryCount: Int { galleryImageIDs.count }

    @discardableResult
    func saveGalleryImage(_ image: UIImage) -> String? {
        var ids = galleryImageIDs
        guard ids.count < 10 else { return nil }
        ensureGalleryDirectoryExists()
        let id = UUID().uuidString
        guard let url = galleryImageURL(id: id) else { return nil }
        let resized = image.resizedToFit(maxDimension: 1200)
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }
        guard (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        ids.insert(id, at: 0)
        galleryImageIDs = ids
        return id
    }

    func loadGalleryImages() -> [(id: String, image: UIImage)] {
        let ids = galleryImageIDs
        var result: [(id: String, image: UIImage)] = []
        for id in ids {
            guard let url = galleryImageURL(id: id),
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                continue
            }
            result.append((id: id, image: image))
        }
        if result.count < ids.count {
            galleryImageIDs = result.map { $0.id }
        }
        return result
    }

    func deleteGalleryImage(id: String) {
        if let url = galleryImageURL(id: id) {
            try? FileManager.default.removeItem(at: url)
        }
        galleryImageIDs = galleryImageIDs.filter { $0 != id }
        if getActiveGalleryID() == id { setActiveGalleryID(nil) }
    }

    func setActiveGalleryID(_ id: String?) {
        if let id = id {
            userDefaults?.set(id, forKey: "activeGalleryID")
        } else {
            userDefaults?.removeObject(forKey: "activeGalleryID")
        }
    }

    func getActiveGalleryID() -> String? {
        userDefaults?.string(forKey: "activeGalleryID")
    }

    // MARK: - Widget Background Image

    /// App Group 컨테이너 내 위젯 배경 이미지 파일 URL
    private var widgetBgImageURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("widget_bg.jpg")
    }

    /// 위젯 배경 이미지 저장 (JPEG 압축, 최대 800px 리사이즈 + 밝기 자동 감지)
    func saveWidgetBackgroundImage(_ image: UIImage) {
        guard let url = widgetBgImageURL else { return }
        let resized = image.resizedToFit(maxDimension: 800)
        guard let data = resized.jpegData(compressionQuality: 0.7) else { return }
        try? data.write(to: url, options: .atomic)
        userDefaults?.set(true, forKey: "hasWidgetBgImage")
        let isDark = resized.averageBrightness() < 0.55
        userDefaults?.set(isDark, forKey: "widgetBgIsDark")
        print("🖼️ [SharedDataManager] 위젯 배경 이미지 저장 완료 (isDark: \(isDark))")
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 위젯 배경 이미지 삭제
    func removeWidgetBackgroundImage() {
        guard let url = widgetBgImageURL else { return }
        try? FileManager.default.removeItem(at: url)
        userDefaults?.removeObject(forKey: "hasWidgetBgImage")
        userDefaults?.removeObject(forKey: "widgetBgIsDark")
        print("🗑️ [SharedDataManager] 위젯 배경 이미지 삭제 완료")
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 위젯 배경 이미지 존재 여부
    func hasWidgetBackgroundImage() -> Bool {
        userDefaults?.bool(forKey: "hasWidgetBgImage") ?? false
    }

    /// 위젯 배경 이미지가 어두운지 여부 (기본: true)
    func isWidgetBgDark() -> Bool {
        guard let defaults = userDefaults,
              defaults.object(forKey: "widgetBgIsDark") != nil else { return true }
        return defaults.bool(forKey: "widgetBgIsDark")
    }

    /// 위젯 배경 이미지 로드 (UIImage)
    func loadWidgetBackgroundImage() -> UIImage? {
        guard let data = loadWidgetBackgroundImageData() else { return nil }
        return UIImage(data: data)
    }

    /// 위젯 배경 이미지 로드 (Data — 위젯 타겟에서 사용)
    func loadWidgetBackgroundImageData() -> Data? {
        guard let url = widgetBgImageURL else { return nil }
        return try? Data(contentsOf: url)
    }

    // MARK: - WorkoutSourcePreference

    func saveWorkoutSourcePreference(_ pref: WorkoutSourcePreference) {
        guard let data = try? JSONEncoder().encode(pref) else { return }
        userDefaults?.set(data, forKey: "workoutSourcePreference")
    }

    func getWorkoutSourcePreference() -> WorkoutSourcePreference {
        guard let data = userDefaults?.data(forKey: "workoutSourcePreference"),
              let pref = try? JSONDecoder().decode(WorkoutSourcePreference.self, from: data) else {
            return WorkoutSourcePreference()
        }
        return pref
    }

    // MARK: - 전체 초기화

    func resetAll() {
        let keys = ["monthlyStats", "goalType", "goalTarget", "runFrequency",
                    "themeAccent", "themeBackground", "distanceUnit",
                    "notificationSettings", "hasWidgetBgImage",
                    "widgetBgIsDark", "widgetDesign", "workoutSourcePreference",
                    "galleryImageIDs", "activeGalleryID",
                    "appLanguage", "journalEntries"]
        keys.forEach { userDefaults?.removeObject(forKey: $0) }
        if let url = widgetBgImageURL { try? FileManager.default.removeItem(at: url) }
        if let dir = galleryDirectoryURL { try? FileManager.default.removeItem(at: dir) }
        UserDefaults.standard.removeObject(forKey: "hkAuthRequested")
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("celebratedMonth_") {
            UserDefaults.standard.removeObject(forKey: key)
        }
        print("🗑️ [SharedDataManager] 전체 데이터 초기화 완료")
    }

    // MARK: - RunJournalEntry

    private let journalKey = "journalEntries"

    func saveJournalEntry(_ entry: RunJournalEntry, for workoutID: UUID) {
        var dict = loadAllJournalEntries()
        dict[workoutID.uuidString] = entry
        guard let data = try? JSONEncoder().encode(dict) else { return }
        userDefaults?.set(data, forKey: journalKey)
    }

    func loadJournalEntry(for workoutID: UUID) -> RunJournalEntry? {
        loadAllJournalEntries()[workoutID.uuidString]
    }

    private func loadAllJournalEntries() -> [String: RunJournalEntry] {
        guard let data = userDefaults?.data(forKey: journalKey),
              let dict = try? JSONDecoder().decode([String: RunJournalEntry].self, from: data)
        else { return [:] }
        return dict
    }
}

// MARK: - UIImage Resize Helper

extension UIImage {
    func resizedToFit(maxDimension: CGFloat) -> UIImage {
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        guard ratio < 1 else { return self }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    /// EXIF orientation을 적용하여 .up으로 정규화 (CGImage.cropping 안전하게 사용 가능)
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(at: .zero) }
    }

    /// 이미지의 평균 밝기(0.0=검정, 1.0=흰색) — 위젯 배경 텍스트 색상 결정용
    func averageBrightness() -> CGFloat {
        let side = 40
        let bytesPerRow = side * 4
        // 명시적 RGBA big-endian + premultipliedLast 컨텍스트 사용 → ptr[0]=R, ptr[1]=G, ptr[2]=B, ptr[3]=A
        guard let context = CGContext(
            data: nil,
            width: side, height: side,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let cgSelf = self.cgImage else { return 0.5 }

        context.draw(cgSelf, in: CGRect(x: 0, y: 0, width: side, height: side))

        guard let ptr = context.data?.assumingMemoryBound(to: UInt8.self) else { return 0.5 }
        let totalPixels = side * side

        var totalLuminance: Double = 0
        for i in 0..<totalPixels {
            let offset = i * 4
            let r = Double(ptr[offset])     / 255.0
            let g = Double(ptr[offset + 1]) / 255.0
            let b = Double(ptr[offset + 2]) / 255.0
            // ITU-R BT.709 luminance
            totalLuminance += 0.2126 * r + 0.7152 * g + 0.0722 * b
        }
        return CGFloat(totalLuminance / Double(totalPixels))
    }
}
