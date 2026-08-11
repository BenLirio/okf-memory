import Foundation
import UserNotifications

/// Mirrors the notification schedule defined in OKF frontmatter into iOS local
/// notifications. The OKF bundle is the source of truth: entries removed from a
/// memory disappear here too.
enum NotificationSync {
    static let idPrefix = "okf-"

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func sync() async {
        guard let items = try? await API.shared.notifications() else { return }
        let center = UNUserNotificationCenter.current()

        let wanted = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, NotificationItem)? in
            guard let date = item.date, date > Date() else { return nil }
            return (idPrefix + item.id, item)
        })

        let pending = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(idPrefix) }
        let stale = pending.map(\.identifier).filter { wanted[$0] == nil }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        let existing = Set(pending.map(\.identifier))
        for (id, item) in wanted where !existing.contains(id) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.userInfo = ["memory_path": item.memory_path]
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: item.date!)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}
