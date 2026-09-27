import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    private var window: NSWindow!
    private var player: PlayerController!
    private var nowPlaying: NowPlaying!
    private var menuBar: MenuBarController!
    private let notifier = TrackNotifier()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [TrackNotifier.defaultsKey: true, "pageZoom": 1.0])

        player = PlayerController()
        nowPlaying = NowPlaying(player: player)
        menuBar = MenuBarController(player: player) { [weak self] in self?.showWindow() }
        notifier.setUp()

        player.onStateChange = { [weak self] in
            self?.nowPlaying.update()
            self?.menuBar.update()
        }
        player.onTrackChange = { [weak self] in
            guard let self else { return }
            self.notifier.trackChanged(self.player.state)
        }

        buildWindow()
        NSApp.mainMenu = buildMainMenu()
        NSApp.activate(ignoringOtherApps: true)
    }

    // Kapatınca müzik çalmaya devam etsin; Dock simgesine tıklayınca pencere geri gelsin.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window.orderOut(nil)
        return false
    }

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "YT Music"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        window.contentView = player.webView
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Menü eylemleri

    @objc private func playPause() { player.togglePlayPause() }
    @objc private func nextTrack() { player.next() }
    @objc private func previousTrack() { player.previous() }
    @objc private func goHome() { player.goHome() }
    @objc private func reload() { player.webView.reload() }
    @objc private func goBack() { player.webView.goBack() }
    @objc private func goForward() { player.webView.goForward() }
    @objc private func zoomIn() { player.setZoom(player.webView.pageZoom + 0.1) }
    @objc private func zoomOut() { player.setZoom(player.webView.pageZoom - 0.1) }
    @objc private func zoomReset() { player.setZoom(1.0) }
    @objc private func toggleNotifications() { notifier.isEnabled.toggle() }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(toggleNotifications):
            item.state = notifier.isEnabled ? .on : .off
        case #selector(playPause):
            item.title = player.state.isPlaying ? "Duraklat" : "Oynat"
        case #selector(goBack):
            return player.webView.canGoBack
        case #selector(goForward):
            return player.webView.canGoForward
        default:
            break
        }
        return true
    }

    // MARK: - Ana menü

    private func buildMainMenu() -> NSMenu {
        let main = NSMenu()

        let app = submenu(in: main, title: "YT Music")
        app.addItem(withTitle: "YT Music Hakkında", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Şarkı Değişince Bildirim Göster", action: #selector(toggleNotifications), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "YT Music'i Gizle", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(item("Diğerlerini Gizle", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        app.addItem(withTitle: "Tümünü Göster", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "YT Music'ten Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Arama kutusunda kopyala/yapıştır çalışsın diye Düzen menüsü şart.
        let edit = submenu(in: main, title: "Düzen")
        edit.addItem(withTitle: "Geri Al", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(item("Yinele", Selector(("redo:")), "z", [.command, .shift]))
        edit.addItem(.separator())
        edit.addItem(withTitle: "Kes", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Kopyala", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Yapıştır", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Tümünü Seç", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let view = submenu(in: main, title: "Görüntü")
        view.addItem(item("Ana Sayfa", #selector(goHome), "h", [.command, .shift]))
        view.addItem(withTitle: "Geri", action: #selector(goBack), keyEquivalent: "[")
        view.addItem(withTitle: "İleri", action: #selector(goForward), keyEquivalent: "]")
        view.addItem(withTitle: "Yenile", action: #selector(reload), keyEquivalent: "r")
        view.addItem(.separator())
        view.addItem(withTitle: "Yakınlaştır", action: #selector(zoomIn), keyEquivalent: "+")
        view.addItem(withTitle: "Uzaklaştır", action: #selector(zoomOut), keyEquivalent: "-")
        view.addItem(withTitle: "Gerçek Boyut", action: #selector(zoomReset), keyEquivalent: "0")
        view.addItem(.separator())
        view.addItem(item("Tam Ekran", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]))

        let playback = submenu(in: main, title: "Oynatma")
        playback.addItem(item("Oynat", #selector(playPause), "p", [.command, .option]))
        playback.addItem(item("Sonraki", #selector(nextTrack), String(Character(UnicodeScalar(NSRightArrowFunctionKey)!)), [.command, .option]))
        playback.addItem(item("Önceki", #selector(previousTrack), String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!)), [.command, .option]))

        let windowMenu = submenu(in: main, title: "Pencere")
        windowMenu.addItem(withTitle: "Kapat", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Küçült", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Büyüt", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(item("YT Music", #selector(showWindow), "1", [.command]))
        NSApp.windowsMenu = windowMenu

        return main
    }

    private func submenu(in main: NSMenu, title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        let holder = NSMenuItem()
        holder.submenu = menu
        main.addItem(holder)
        return menu
    }

    private func item(_ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }
}
