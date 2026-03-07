import Foundation

// MARK: - SampleData

enum SampleData {

    // MARK: - Sample Dashboards

    static var allDashboards: [Dashboard] {
        [mediaControlDashboard, presentationDashboard, productivityDashboard, developerDashboard]
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

    static var developerDashboard: Dashboard {
        Dashboard(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000004")!,
            name: "Developer",
            icon: "terminal.fill",
            colorHex: "#000000",
            pages: [
                DashboardPage(
                    title: "Tools",
                    buttons: [
                        DeskButton(title: "Terminal",    icon: "terminal.fill",                              colorHex: "#000000", action: .openTerminal,                          position: 0),
                        DeskButton(title: "Xcode",       icon: "hammer.fill",                                colorHex: "#147EFB", action: .openApp(appID: "xcode"),               position: 1),
                        DeskButton(title: "VS Code",     icon: "chevron.left.forwardslash.chevron.right",    colorHex: "#007ACC", action: .openApp(appID: "vscode"),              position: 2),
                        DeskButton(title: "Dark Mode",   icon: "circle.lefthalf.filled",                     colorHex: "#5856D6", action: .toggleDarkMode,                       position: 3),
                        DeskButton(title: "Screenshot",  icon: "camera.viewfinder",                          colorHex: "#FF3B30", action: .screenshot,                            position: 4),
                        DeskButton(title: "DND",         icon: "moon.fill",                                  colorHex: "#AF52DE", action: .toggleDoNotDisturb,                   position: 5),
                        DeskButton(title: "GitHub",      icon: "arrow.triangle.branch",                      colorHex: "#6E5494", action: .openApp(appID: "github_desktop"),      position: 6),
                        DeskButton(title: "Figma",       icon: "paintbrush.pointed.fill",                    colorHex: "#F24E1E", action: .openApp(appID: "figma"),               position: 7),
                        DeskButton(title: "Sleep",       icon: "display",                                    colorHex: "#636366", action: .sleepDisplay,                         position: 8)
                    ]
                ),
                DashboardPage(
                    title: "Mac",
                    buttons: [
                        DeskButton(title: "Finder",      icon: "folder.fill",         colorHex: "#007AFF", action: .openApp(appID: "finder"),             position: 0),
                        DeskButton(title: "Settings",    icon: "gearshape.fill",      colorHex: "#636366", action: .openApp(appID: "system_settings"),   position: 1),
                        DeskButton(title: "Activity",    icon: "chart.bar.fill",      colorHex: "#34C759", action: .openApp(appID: "activity_monitor"),  position: 2),
                        DeskButton(title: "Console",     icon: "text.alignleft",      colorHex: "#636366", action: .openApp(appID: "console"),           position: 3),
                        DeskButton(title: "Keynote",     icon: "play.rectangle.fill", colorHex: "#007AFF", action: .openApp(appID: "keynote"),           position: 4),
                        DeskButton(title: "Pages",       icon: "doc.richtext.fill",   colorHex: "#FF9500", action: .openApp(appID: "pages"),             position: 5),
                        DeskButton(title: "Numbers",     icon: "tablecells.fill",     colorHex: "#34C759", action: .openApp(appID: "numbers"),           position: 6),
                        DeskButton(title: "Force Quit",  icon: "xmark.octagon.fill",      colorHex: "#FF3B30", action: .forceQuitApp,                        position: 7),
                        DeskButton(title: "Trash",       icon: "trash.fill",          colorHex: "#FF3B30", action: .emptyTrash,                          position: 8)
                    ]
                )
            ]
        )
    }
}