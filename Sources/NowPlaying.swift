import AppKit
import MediaPlayer

/// Klavyedeki medya tuşları ve Kontrol Merkezi'ndeki "Şimdi Çalınıyor" alanı.
final class NowPlaying {
    private let player: PlayerController
    private let center = MPNowPlayingInfoCenter.default()
    private var artwork: MPMediaItemArtwork?
    private var artworkSource: NSImage?
    private var lastToggle = Date.distantPast

    init(player: PlayerController) {
        self.player = player
        let commands = MPRemoteCommandCenter.shared()

        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            // Aynı tuş basışı iki kez gelirse çift tetiklemeyi önle.
            guard Date().timeIntervalSince(self.lastToggle) > 0.3 else { return .success }
            self.lastToggle = Date()
            DispatchQueue.main.async { self.player.togglePlayPause() }
            return .success
        }
        commands.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.player.play() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.player.pause() }
            return .success
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.player.next() }
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.player.previous() }
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            DispatchQueue.main.async { self?.player.seek(to: event.positionTime) }
            return .success
        }
    }

    func update() {
        let s = player.state
        guard s.hasTrack else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: s.title,
            MPMediaItemPropertyArtist: s.artist,
            MPMediaItemPropertyAlbumTitle: s.album,
            MPMediaItemPropertyPlaybackDuration: s.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: s.position,
            MPNowPlayingInfoPropertyPlaybackRate: s.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]

        if let image = s.artwork {
            if image !== artworkSource {
                artworkSource = image
                artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        center.nowPlayingInfo = info
        center.playbackState = s.isPlaying ? .playing : .paused
    }
}
