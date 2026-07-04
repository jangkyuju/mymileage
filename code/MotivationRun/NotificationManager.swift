//
//  NotificationManager.swift
//  MotivationRun
//
//  ⚠️ 메인 앱 타겟만 포함 (위젯 타겟 불필요)
//

import UserNotifications
import Foundation

class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    // MARK: - 시스템 권한 요청

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ [Notification] 권한 요청 오류: \(error.localizedDescription)")
            }
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// 아직 권한을 물어본 적 없을 때(.notDetermined)만 요청.
    /// 이미 결정된 경우 현재 허용 여부를 그대로 반환 (중복 팝업 방지).
    func requestAuthorizationIfNotDetermined(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            switch s.authorizationStatus {
            case .notDetermined:
                self.requestAuthorization(completion: completion)
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion(true) }
            default:
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    // MARK: - 매일 습관 알림 (하루 1회)

    /// 오늘부터 7일치, 하루 1회 `reminderHour`시 알림 예약.
    /// - 일회성(repeats:false)이라 앱 진입 시 롤링으로 재예약된다.
    func scheduleDailyReminder(hasRunToday: Bool, settings: NotificationSettings) {
        cancelDailyReminder()
        guard settings.isEnabled else { return }
        let lang = SharedDataManager.shared.getLanguage()
        let messages = dailyReminderMessages(lang: lang)
        let startOffset = hasRunToday ? 1 : 0
        for i in 0..<7 {
            let day = startOffset + i
            scheduleDailyNotif(
                id: "daily_\(day)",
                dayOffset: day,
                hour: settings.reminderHour,
                minute: settings.reminderMinute,
                body: messages[i % messages.count]
            )
        }
    }

    func cancelDailyReminder() {
        // 현재 daily_* + 레거시 retention_* 모두 청소 (업그레이드 대비)
        let ids = (0..<8).flatMap { i in
            ["daily_\(i)", "retention_am_\(i)", "retention_pm_\(i)"]
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func scheduleDailyNotif(id: String, dayOffset: Int, hour: Int, minute: Int, body: String) {
        let calendar = Calendar.current
        let now = Date()
        guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { return }
        var comps = calendar.dateComponents([.year, .month, .day], from: targetDate)
        comps.hour   = hour
        comps.minute = minute
        // Skip if fire time already passed today
        guard let fireDate = calendar.date(from: comps), fireDate > now else { return }
        let content = UNMutableNotificationContent()
        content.title = L(.notifTitle, SharedDataManager.shared.getLanguage())
        content.body  = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [DailyReminder] 등록 실패 (\(id)): \(error.localizedDescription)")
            }
        }
    }

    private func dailyReminderMessages(lang: AppLanguage) -> [String] {
        return [
            L(.dailyReminder1, lang),
            L(.dailyReminder2, lang),
            L(.dailyReminder3, lang),
            L(.dailyReminder4, lang),
            L(.dailyReminder5, lang),
            L(.dailyReminder6, lang),
        ]
    }

}
