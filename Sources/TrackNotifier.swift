import AppKit
import UserNotifications

/// Şarkı değişince (uygulama arka plandayken) bildirim gösterir.
final class TrackNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let defaultsKey = "notifications"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.defaultsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.defaultsKey)
            if newValue { requestAuthorization() }
        }
    }

    private var center: UNUserNotificationCenter { .current() }

    func setUp() {
        center.delegate = self
        if isEnabled { requestAuthorization() }
    }

    private func requestAuthorization() {
        center.requestAuthorization(options: [.alert]) { _, _ in }
    }

    func trackChanged(_ state: PlayerState) {
        guard isEnabled else { return }
        let title = state.title
        // Kapak görselinin yüklenmesi için kısa bir süre bekle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, state.title == title, state.isPlaying, !NSApp.isActive else { return }
            self.post(title: title, artist: state.artist, artwork: state.artwork)
        }
    }

    private func post(title: String, artist: String, artwork: NSImage?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = artist
        if let attachment = artwork.flatMap(Self.attachment) {
            content.attachments = [attachment]
        }
        // Aynı kimlik: yeni bildirim eskisinin yerine geçer, bildirim merkezi dolmaz.
        let request = UNNotificationRequest(identifier: "now-playing", content: content, trigger: nil)
        center.add(request)
    }

    private static func attachment(for image: NSImage) -> UNNotificationAttachment? {
        guard let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("artwork-\(UUID().uuidString).png")
        guard (try? png.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "artwork", url: url)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { (NSApp.delegate as? AppDelegate)?.showWindow() }
        completionHandler()
    }
}
