import AppKit
import SwiftUI

/// Menü çubuğundaki simge: sol tık mini oynatıcı, sağ tık hızlı menü.
final class MenuBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let player: PlayerController
    private let openWindow: () -> Void

    init(player: PlayerController, openWindow: @escaping () -> Void) {
        self.player = player
        self.openWindow = openWindow
        super.init()

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "YT Music")
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MiniPlayerView(
            state: player.state,
            player: player,
            openWindow: { [weak self] in
                self?.popover.performClose(nil)
                openWindow()
            }
        ))
    }

    func update() {
        // Çalmıyorken simge soluk görünür.
        item.button?.appearsDisabled = !player.state.isPlaying
        item.button?.toolTip = player.state.hasTrack ? "\(player.state.title) — \(player.state.artist)" : "YT Music"
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else if popover.isShown {
            popover.performClose(nil)
        } else if let button = item.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: player.state.isPlaying ? "Duraklat" : "Oynat", action: #selector(toggle), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Sonraki", action: #selector(next), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Önceki", action: #selector(previous), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Pencereyi Aç", action: #selector(open), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil // Sol tık yine mini oynatıcıyı açsın.
    }

    @objc private func toggle() { player.togglePlayPause() }
    @objc private func next() { player.next() }
    @objc private func previous() { player.previous() }
    @objc private func open() { openWindow() }
}

/// Sürgü sürüklenirken gösterilen konum. (@State makrosu Command Line Tools'ta
/// derlenmediği için küçük bir model kullanıyoruz.)
final class ScrubState: ObservableObject {
    @Published var position: Double?
}

struct MiniPlayerView: View {
    @ObservedObject var state: PlayerState
    let player: PlayerController
    let openWindow: () -> Void

    @StateObject private var scrub = ScrubState()

    var body: some View {
        VStack(spacing: 14) {
            artwork

            VStack(spacing: 3) {
                Text(state.hasTrack ? state.title : "Çalan şarkı yok")
                    .font(.headline)
                    .lineLimit(1)
                Text(state.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            progress

            HStack(spacing: 32) {
                controlButton("backward.fill", size: 20, action: player.previous)
                controlButton(state.isPlaying ? "pause.circle.fill" : "play.circle.fill", size: 40, action: player.togglePlayPause)
                controlButton("forward.fill", size: 20, action: player.next)
            }
            .disabled(!state.hasTrack)

            Divider()

            HStack {
                Button("Pencereyi aç", action: openWindow)
                Spacer()
                Button("Çık") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
        .padding(16)
        .frame(width: 280)
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.15))
            if let image = state.artwork {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note").font(.system(size: 56)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 248, height: 248)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var progress: some View {
        let duration = max(state.duration, 1)
        let position = min(scrub.position ?? state.position, duration)
        return VStack(spacing: 2) {
            Slider(
                value: Binding(get: { position }, set: { scrub.position = $0 }),
                in: 0...duration,
                onEditingChanged: { editing in
                    if !editing, let target = scrub.position {
                        player.seek(to: target)
                        scrub.position = nil
                    }
                }
            )
            .controlSize(.small)
            HStack {
                Text(Self.format(position))
                Spacer()
                Text(Self.format(state.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .disabled(state.duration == 0)
    }

    private func controlButton(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size))
        }
        .buttonStyle(.plain)
    }

    private static func format(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
