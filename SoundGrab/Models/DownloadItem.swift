import Foundation

nonisolated enum DownloadStatus: Sendable, Equatable {
    case idle
    case extracting
    case downloading(progress: Double)
    case converting
    case completed(fileURL: URL)
    case failed(message: String)

    var isActive: Bool {
        switch self {
        case .extracting, .downloading, .converting: return true
        default: return false
        }
    }
}

struct DownloadItem: Identifiable, Sendable {
    let id: UUID
    let videoID: String
    var title: String
    var thumbnailURL: URL?
    var duration: String?
    var status: DownloadStatus
    var addedAt: Date

    init(videoID: String, title: String = "", thumbnailURL: URL? = nil) {
        self.id = UUID()
        self.videoID = videoID
        self.title = title.isEmpty ? videoID : title
        self.thumbnailURL = thumbnailURL
        self.status = .idle
        self.addedAt = Date()
    }
}
