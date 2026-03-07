import Foundation

struct AppShortcut: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let urlScheme: String
    let icon: String
    let colorHex: String
    let category: AppCategory
    let iconURL: String?

    init(
        id: String,
        name: String,
        urlScheme: String,
        icon: String,
        colorHex: String,
        category: AppCategory,
        iconURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.urlScheme = urlScheme
        self.icon = icon
        self.colorHex = colorHex
        self.category = category
        self.iconURL = iconURL
    }
}

enum AppCategory: String, CaseIterable, Sendable {
    case social = "Social"
    case entertainment = "Entertainment"
    case productivity = "Productivity"
    case communication = "Communication"
    case utilities = "Utilities"
    case creative = "Creative"
    case education = "Education"
    case shopping = "Shopping"
    case health = "Health"
    case news = "News"
    case developer = "Developer"

    var systemImage: String {
        switch self {
        case .social:         return "person.2.fill"
        case .entertainment:  return "play.tv.fill"
        case .productivity:   return "briefcase.fill"
        case .communication:  return "message.fill"
        case .utilities:      return "wrench.and.screwdriver.fill"
        case .creative:       return "paintbrush.fill"
        case .education:      return "graduationcap.fill"
        case .shopping:       return "cart.fill"
        case .health:         return "heart.fill"
        case .news:           return "newspaper.fill"
        case .developer:      return "terminal.fill"
        }
    }
}

enum AppCatalog {
    static let allApps: [AppShortcut] = [
        AppShortcut(id: "youtube", name: "YouTube", urlScheme: "youtube://", icon: "play.rectangle.fill", colorHex: "#FF0000", category: .entertainment),
        AppShortcut(id: "spotify", name: "Spotify", urlScheme: "spotify://", icon: "music.note", colorHex: "#1DB954", category: .entertainment),
        AppShortcut(id: "netflix", name: "Netflix", urlScheme: "nflx://", icon: "play.tv.fill", colorHex: "#E50914", category: .entertainment),
        AppShortcut(id: "tiktok", name: "TikTok", urlScheme: "snssdk1128://", icon: "music.note.tv", colorHex: "#000000", category: .entertainment),
        AppShortcut(id: "twitch", name: "Twitch", urlScheme: "twitch://", icon: "play.display", colorHex: "#9146FF", category: .entertainment),
        AppShortcut(id: "disney", name: "Disney+", urlScheme: "disneyplus://", icon: "sparkles.tv.fill", colorHex: "#113CCF", category: .entertainment),
        AppShortcut(id: "apple_music", name: "Apple Music", urlScheme: "music://", icon: "music.note", colorHex: "#FC3C44", category: .entertainment),
        AppShortcut(id: "apple_tv", name: "Apple TV", urlScheme: "videos://", icon: "play.tv", colorHex: "#000000", category: .entertainment),
        AppShortcut(id: "podcasts", name: "Podcasts", urlScheme: "podcasts://", icon: "antenna.radiowaves.left.and.right", colorHex: "#9B59B6", category: .entertainment),

        AppShortcut(id: "instagram", name: "Instagram", urlScheme: "instagram://", icon: "camera.fill", colorHex: "#E4405F", category: .social),
        AppShortcut(id: "twitter", name: "X (Twitter)", urlScheme: "twitter://", icon: "at", colorHex: "#000000", category: .social),
        AppShortcut(id: "facebook", name: "Facebook", urlScheme: "fb://", icon: "person.2.fill", colorHex: "#1877F2", category: .social),
        AppShortcut(id: "snapchat", name: "Snapchat", urlScheme: "snapchat://", icon: "camera.viewfinder", colorHex: "#FFFC00", category: .social),
        AppShortcut(id: "reddit", name: "Reddit", urlScheme: "reddit://", icon: "bubble.left.and.bubble.right.fill", colorHex: "#FF4500", category: .social),
        AppShortcut(id: "linkedin", name: "LinkedIn", urlScheme: "linkedin://", icon: "briefcase.fill", colorHex: "#0A66C2", category: .social),
        AppShortcut(id: "pinterest", name: "Pinterest", urlScheme: "pinterest://", icon: "pin.fill", colorHex: "#BD081C", category: .social),
        AppShortcut(id: "threads", name: "Threads", urlScheme: "barcelona://", icon: "at.circle.fill", colorHex: "#000000", category: .social),

        AppShortcut(id: "whatsapp", name: "WhatsApp", urlScheme: "whatsapp://", icon: "phone.fill", colorHex: "#25D366", category: .communication),
        AppShortcut(id: "telegram", name: "Telegram", urlScheme: "tg://", icon: "paperplane.fill", colorHex: "#0088CC", category: .communication),
        AppShortcut(id: "messenger", name: "Messenger", urlScheme: "fb-messenger://", icon: "bubble.fill", colorHex: "#0084FF", category: .communication),
        AppShortcut(id: "discord", name: "Discord", urlScheme: "discord://", icon: "headphones", colorHex: "#5865F2", category: .communication),
        AppShortcut(id: "slack", name: "Slack", urlScheme: "slack://", icon: "number", colorHex: "#4A154B", category: .communication),
        AppShortcut(id: "teams", name: "Teams", urlScheme: "msteams://", icon: "person.3.fill", colorHex: "#6264A7", category: .communication),
        AppShortcut(id: "zoom", name: "Zoom", urlScheme: "zoomus://", icon: "video.fill", colorHex: "#2D8CFF", category: .communication),
        AppShortcut(id: "facetime", name: "FaceTime", urlScheme: "facetime://", icon: "video.fill", colorHex: "#34C759", category: .communication),
        AppShortcut(id: "mail", name: "Mail", urlScheme: "message://", icon: "envelope.fill", colorHex: "#007AFF", category: .communication),

        AppShortcut(id: "safari", name: "Safari", urlScheme: "x-web-search://", icon: "safari.fill", colorHex: "#007AFF", category: .utilities),
        AppShortcut(id: "chrome", name: "Chrome", urlScheme: "googlechrome://", icon: "globe", colorHex: "#4285F4", category: .utilities),
        AppShortcut(id: "maps", name: "Maps", urlScheme: "maps://", icon: "map.fill", colorHex: "#34C759", category: .utilities),
        AppShortcut(id: "google_maps", name: "Google Maps", urlScheme: "comgooglemaps://", icon: "map.fill", colorHex: "#4285F4", category: .utilities),
        AppShortcut(id: "calculator", name: "Calculator", urlScheme: "calc://", icon: "plusminus", colorHex: "#636366", category: .utilities),
        AppShortcut(id: "files", name: "Files", urlScheme: "shareddocuments://", icon: "folder.fill", colorHex: "#007AFF", category: .utilities),
        AppShortcut(id: "settings", name: "Settings", urlScheme: "App-prefs://", icon: "gearshape.fill", colorHex: "#636366", category: .utilities),
        AppShortcut(id: "shortcuts", name: "Shortcuts", urlScheme: "shortcuts://", icon: "square.stack.3d.up.fill", colorHex: "#FF2D55", category: .utilities),
        AppShortcut(id: "clock", name: "Clock", urlScheme: "clock-alarm://", icon: "clock.fill", colorHex: "#000000", category: .utilities),
        AppShortcut(id: "camera", name: "Camera", urlScheme: "camera://", icon: "camera.fill", colorHex: "#636366", category: .utilities),
        AppShortcut(id: "photos", name: "Photos", urlScheme: "photos-redirect://", icon: "photo.fill", colorHex: "#FF9500", category: .utilities),

        AppShortcut(id: "notes", name: "Notes", urlScheme: "mobilenotes://", icon: "note.text", colorHex: "#FFD60A", category: .productivity),
        AppShortcut(id: "reminders", name: "Reminders", urlScheme: "x-apple-reminderkit://", icon: "checklist", colorHex: "#007AFF", category: .productivity),
        AppShortcut(id: "calendar", name: "Calendar", urlScheme: "calshow://", icon: "calendar", colorHex: "#FF3B30", category: .productivity),
        AppShortcut(id: "notion", name: "Notion", urlScheme: "notion://", icon: "doc.text.fill", colorHex: "#000000", category: .productivity),
        AppShortcut(id: "google_docs", name: "Google Docs", urlScheme: "googledocs://", icon: "doc.fill", colorHex: "#4285F4", category: .productivity),
        AppShortcut(id: "google_drive", name: "Google Drive", urlScheme: "googledrive://", icon: "externaldrive.fill", colorHex: "#0F9D58", category: .productivity),
        AppShortcut(id: "dropbox", name: "Dropbox", urlScheme: "dbapi-1://", icon: "shippingbox.fill", colorHex: "#0061FF", category: .productivity),
        AppShortcut(id: "trello", name: "Trello", urlScheme: "trello://", icon: "rectangle.split.3x3.fill", colorHex: "#0052CC", category: .productivity),

        AppShortcut(id: "amazon", name: "Amazon", urlScheme: "com.amazon.mobile.shopping://", icon: "cart.fill", colorHex: "#FF9900", category: .shopping),
        AppShortcut(id: "ebay", name: "eBay", urlScheme: "ebay://", icon: "bag.fill", colorHex: "#E53238", category: .shopping),

        AppShortcut(id: "health", name: "Health", urlScheme: "x-apple-health://", icon: "heart.fill", colorHex: "#FF2D55", category: .health),
        AppShortcut(id: "fitness", name: "Fitness", urlScheme: "fitnessapp://", icon: "figure.run", colorHex: "#34C759", category: .health),

        AppShortcut(id: "procreate", name: "Procreate", urlScheme: "procreate://", icon: "paintbrush.pointed.fill", colorHex: "#000000", category: .creative),
        AppShortcut(id: "garageband", name: "GarageBand", urlScheme: "garageband://", icon: "guitars.fill", colorHex: "#FF9500", category: .creative),
        AppShortcut(id: "imovie", name: "iMovie", urlScheme: "imovie://", icon: "film.fill", colorHex: "#5856D6", category: .creative),

        AppShortcut(id: "duolingo", name: "Duolingo", urlScheme: "duolingo://", icon: "character.book.closed.fill", colorHex: "#58CC02", category: .education),

        AppShortcut(id: "apple_news", name: "Apple News", urlScheme: "applenews://", icon: "newspaper.fill", colorHex: "#FF2D55", category: .news),

        AppShortcut(id: "figma", name: "Figma", urlScheme: "figma://", icon: "paintbrush.pointed.fill", colorHex: "#F24E1E", category: .developer),
        AppShortcut(id: "github_desktop", name: "GitHub Desktop", urlScheme: "x-github-client://", icon: "arrow.triangle.branch", colorHex: "#6E5494", category: .developer),
    ]

    static func apps(for category: AppCategory) -> [AppShortcut] {
        allApps.filter { $0.category == category }
    }

    static func app(withID id: String) -> AppShortcut? {
        allApps.first { $0.id == id }
    }

    static func search(_ query: String) -> [AppShortcut] {
        guard !query.isEmpty else { return allApps }
        let q = query.lowercased()
        return allApps.filter { $0.name.lowercased().contains(q) }
    }
}
