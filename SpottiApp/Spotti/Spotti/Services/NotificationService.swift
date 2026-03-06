import AppKit
import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { granted, error in
            if let error {
                NSLog("[NotificationService] Permission error: %@", error.localizedDescription)
            }
        }
    }

    func showTrackNotification(title: String, artist: String, album: String, imageUrl: String?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = artist
        content.body = album
        content.categoryIdentifier = "TRACK_CHANGE"

        if let urlStr = imageUrl, let url = URL(string: urlStr) {
            Task.detached(priority: .utility) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileURL = tempDir.appendingPathComponent("spotti_notif_art.jpg")
                    try data.write(to: fileURL)
                    let attachment = try UNNotificationAttachment(
                        identifier: "albumArt",
                        url: fileURL,
                        options: nil
                    )
                    content.attachments = [attachment]
                    self.deliver(content: content)
                } catch {
                    self.deliver(content: content)
                }
            }
        } else {
            deliver(content: content)
        }
    }

    private func deliver(content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(
            identifier: "spotti-track-change",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let isActive = await MainActor.run { NSApp.isActive }
        if isActive {
            return []
        }
        return [.banner]
    }
}
