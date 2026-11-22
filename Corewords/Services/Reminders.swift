import Foundation
import UserNotifications

/// Daily study reminders as local notifications. The next 14 days are scheduled one by one so each message can
/// say how many reviews will be waiting; they are rescheduled whenever the app goes to the background.
enum Reminders {
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(_ progress: ProgressData, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard progress.settings.remindersOn else { return }
        let cal = Calendar.current
        let today = progress.log(on: now)
        let goalMetToday = today.answers >= progress.settings.dailyGoal
        for offset in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: offset, to: now),
                  var fire = cal.date(bySettingHour: progress.settings.reminderHour, minute: progress.settings.reminderMinute, second: 0, of: day)
            else { continue }
            if offset == 0 && (fire <= now || goalMetToday) { continue }
            if fire <= now { fire = fire.addingTimeInterval(86400) }
            let due = progress.dueCount(on: fire)
            let streak = progress.streak(now: now)
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Time for your English words")
            if due > 0 {
                content.body = String(localized: "\(due) words are ready for review. A few minutes keeps them in your memory.")
            } else {
                content.body = String(localized: "Learn a few new words today. The most useful ones come first.")
            }
            if streak > 1 && offset <= 1 {
                content.body += " " + String(localized: "Keep your \(streak)-day streak going!")
            }
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "study-\(offset)", content: content, trigger: trigger))
        }
    }
}
