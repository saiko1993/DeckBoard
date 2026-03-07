import Foundation
import MediaPlayer
import UIKit

@MainActor
final class MediaControlService {

    static let shared = MediaControlService()
    private var volumeView: MPVolumeView?
    private let musicPlayer = MPMusicPlayerController.systemMusicPlayer

    private init() {
        setupVolumeView()
    }

    private func setupVolumeView() {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        view.isHidden = true
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first {
            window.addSubview(view)
        }
        volumeView = view
    }

    private var volumeSlider: UISlider? {
        volumeView?.subviews.compactMap { $0 as? UISlider }.first
    }

    func volumeUp() {
        if let slider = volumeSlider {
            let newValue = min(slider.value + 0.0625, 1.0)
            slider.value = newValue
            slider.sendActions(for: .valueChanged)
        }
    }

    func volumeDown() {
        if let slider = volumeSlider {
            let newValue = max(slider.value - 0.0625, 0.0)
            slider.value = newValue
            slider.sendActions(for: .valueChanged)
        }
    }

    func mute() {
        if let slider = volumeSlider {
            slider.value = 0.0
            slider.sendActions(for: .valueChanged)
        }
    }

    func brightnessUp() {
        UIScreen.main.brightness = min(UIScreen.main.brightness + 0.1, 1.0)
    }

    func brightnessDown() {
        UIScreen.main.brightness = max(UIScreen.main.brightness - 0.1, 0.0)
    }

    func mediaPlay() {
        musicPlayer.play()
    }

    func mediaPause() {
        musicPlayer.pause()
    }

    func mediaPlayPause() {
        if musicPlayer.playbackState == .playing {
            musicPlayer.pause()
        } else {
            musicPlayer.play()
        }
    }

    func mediaNext() {
        musicPlayer.skipToNextItem()
    }

    func mediaPrevious() {
        musicPlayer.skipToPreviousItem()
    }

    func mediaSkipForward() {
        musicPlayer.currentPlaybackTime += 15
    }

    func mediaSkipBackward() {
        let newTime = max(musicPlayer.currentPlaybackTime - 15, 0)
        musicPlayer.currentPlaybackTime = newTime
    }

    func openApp(scheme: String) async -> Bool {
        guard let url = URL(string: scheme) else { return false }
        return await UIApplication.shared.open(url)
    }

    func openAppByID(_ appID: String) async -> Bool {
        guard let app = AppCatalog.app(withID: appID) else { return false }
        return await openApp(scheme: app.urlScheme)
    }

    func runShortcut(name: String) async -> Bool {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let shortcutURL = "shortcuts://run-shortcut?name=\(encoded)"
        guard let url = URL(string: shortcutURL) else { return false }
        return await UIApplication.shared.open(url)
    }
}
