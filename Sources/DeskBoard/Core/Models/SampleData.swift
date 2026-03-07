import Foundation

// MARK: - SampleData

enum SampleData {

    // MARK: - Sample Dashboards

    static var allDashboards: [Dashboard] {
        [mediaControlDashboard, presentationDashboard, productivityDashboard]
    }

    static var mediaControlDashboard: Dashboard {
        Dashboard(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000001")!,
            name: "Media Control",
            icon: "music.note",
            colorHex: "#AF52DE",
            pages: [
                DashboardPage(
                    title: "Playback",
                    buttons: [
                        DeskButton(title: "Previous",   icon: "backward.fill",     colorHex: "#636366", action: .mediaPrevious,   position: 0),
                        DeskButton(title: "Play/Pause", icon: "playpause.fill",    colorHex: "#007AFF", action: .mediaPlayPause,  position: 1),
                        DeskButton(title: "Next",       icon: "forward.fill",      colorHex: "#636366", action: .mediaNext,       position: 2),
                        DeskButton(title: "Vol Down",   icon: "speaker.minus.fill",colorHex: "#34C759", action: .mediaVolumeDown, position: 3),
                        DeskButton(title: "Play",       icon: "play.fill",         colorHex: "#34C759", action: .mediaPlay,       position: 4),
                        DeskButton(title: "Vol Up",     icon: "speaker.plus.fill", colorHex: "#34C759", action: .mediaVolumeUp,   position: 5)
                    ]
                )
            ]
        )
    }

    static var presentationDashboard: Dashboard {
        Dashboard(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000002")!,
            name: "Presentation",
            icon: "rectangle.on.rectangle",
            colorHex: "#FF3B30",
            pages: [
                DashboardPage(
                    title: "Slides",
                    buttons: [
                        DeskButton(title: "Prev Slide", icon: "arrow.left.circle.fill",  colorHex: "#636366", action: .presentationPrevious, position: 0),
                        DeskButton(title: "Next Slide", icon: "arrow.right.circle.fill", colorHex: "#007AFF", action: .presentationNext,     position: 1),
                        DeskButton(title: "Start",      icon: "play.rectangle.fill",     colorHex: "#34C759", action: .presentationStart,    position: 2),
                        DeskButton(title: "End",        icon: "stop.circle.fill",        colorHex: "#FF3B30", action: .presentationEnd,      position: 3)
                    ]
                )
            ]
        )
    }

    static var productivityDashboard: Dashboard {
        Dashboard(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000003")!,
            name: "Shortcuts",
            icon: "bolt.fill",
            colorHex: "#FF9500",
            pages: [
                DashboardPage(
                    title: "Main",
                    buttons: [
                        DeskButton(title: "Google",  icon: "magnifyingglass",      colorHex: "#007AFF", action: .openURL(url: "https://google.com"),  position: 0),
                        DeskButton(title: "GitHub",  icon: "chevron.left.forwardslash.chevron.right", colorHex: "#636366", action: .openURL(url: "https://github.com"), position: 1),
                        DeskButton(title: "Notes",   icon: "note.text",             colorHex: "#FFD60A", action: .openDeepLink(url: "mobilenotes://"), position: 2),
                        DeskButton(title: "Hello!",  icon: "hand.wave.fill",        colorHex: "#AF52DE", action: .sendText(text: "Hello! 👋"),         position: 3),
                        DeskButton(title: "Meeting", icon: "video.fill",            colorHex: "#34C759", action: .sendText(text: "Joining the meeting now"), position: 4),
                        DeskButton(title: "BRB",     icon: "clock.fill",            colorHex: "#FF9500", action: .sendText(text: "Be right back"),     position: 5)
                    ]
                )
            ]
        )
    }
}