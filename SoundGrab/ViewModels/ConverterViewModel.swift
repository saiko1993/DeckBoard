import Foundation
import SwiftUI
import AVFoundation

@Observable
@MainActor
class ConverterViewModel {
    var urlText: String = ""
    var items: [DownloadItem] = []
    var showingError: Bool = false
    var errorMessage: String = ""
    var showingShareSheet: Bool = false
    var shareURL: URL?

    var hasActiveDownloads: Bool {
        items.contains { $0.status.isActive }
    }

    var completedItems: [DownloadItem] {
        items.filter {
            if case .completed = $0.status { return true }
            return false
        }
    }

    func addAndProcess() {
        let input = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        guard let videoID = YouTubeExtractor.extractVideoID(from: input) else {
            errorMessage = "Invalid YouTube URL. Please enter a valid link."
            showingError = true
            return
        }

        if items.contains(where: { $0.videoID == videoID && $0.status.isActive }) {
            errorMessage = "This video is already being processed."
            showingError = true
            return
        }

        var item = DownloadItem(videoID: videoID)
        item.status = .extracting
        items.insert(item, at: 0)
        urlText = ""

        let itemID = item.id
        Task {
            await processItem(id: itemID, videoID: videoID)
        }
    }

    func retryItem(_ item: DownloadItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].status = .extracting

        let itemID = item.id
        let videoID = item.videoID
        Task {
            await processItem(id: itemID, videoID: videoID)
        }
    }

    func removeItem(_ item: DownloadItem) {
        items.removeAll { $0.id == item.id }
    }

    func shareFile(at url: URL) {
        shareURL = url
        showingShareSheet = true
    }

    func clearCompleted() {
        items.removeAll {
            if case .completed = $0.status { return true }
            if case .failed = $0.status { return true }
            return false
        }
    }

    private func processItem(id: UUID, videoID: String) async {
        do {
            let extracted = try await YouTubeExtractor.extractAudio(videoID: videoID)

            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            items[index].title = extracted.title
            items[index].thumbnailURL = extracted.thumbnailURL
            items[index].duration = extracted.duration
            items[index].status = .downloading(progress: 0)

            let outputURL = try await AudioConverter.shared.downloadAndConvert(
                streamURL: extracted.streamURL,
                title: extracted.title,
                fileExtension: extracted.fileExtension
            ) { [weak self] progress in
                guard let self, let idx = self.items.firstIndex(where: { $0.id == id }) else { return }
                if progress < 0.9 {
                    self.items[idx].status = .downloading(progress: progress)
                } else {
                    self.items[idx].status = .converting
                }
            }

            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            items[index].status = .completed(fileURL: outputURL)
        } catch {
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            items[index].status = .failed(message: error.localizedDescription)
        }
    }


}
