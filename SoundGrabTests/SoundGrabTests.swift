//
//  SoundGrabTests.swift
//  SoundGrabTests
//
//  Created by Rork on March 5, 2026.
//

import Testing
import Foundation
@testable import SoundGrab

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - extractVideoID
// ─────────────────────────────────────────────────────────────────────────────

@Suite("YouTubeExtractor.extractVideoID")
struct ExtractVideoIDTests {

    // Valid standard watch URLs
    @Test("Standard watch URL")
    func standardWatchURL() {
        let id = YouTubeExtractor.extractVideoID(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        #expect(id == "dQw4w9WgXcQ")
    }

    @Test("Watch URL with extra params")
    func watchURLWithExtraParams() {
        let id = YouTubeExtractor.extractVideoID(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLx&index=1")
        #expect(id == "dQw4w9WgXcQ")
    }

    @Test("HTTP (non-HTTPS) watch URL")
    func httpWatchURL() {
        let id = YouTubeExtractor.extractVideoID(from: "http://www.youtube.com/watch?v=dQw4w9WgXcQ")
        #expect(id == "dQw4w9WgXcQ")
    }

    @Test("Mobile m.youtube.com URL")
    func mobileURL() {
        let id = YouTubeExtractor.extractVideoID(from: "https://m.youtube.com/watch?v=dQw4w9WgXcQ")
        #expect(id == "dQw4w9WgXcQ")
    }

    // Short youtu.be URLs
    @Test("Short youtu.be URL")
    func shortURL() {
        let id = YouTubeExtractor.extractVideoID(from: "https://youtu.be/dQw4w9WgXcQ")
        #expect(id == "dQw4w9WgXcQ")
    }

    @Test("Short youtu.be URL with timestamp")
    func shortURLWithTimestamp() {
        let id = YouTubeExtractor.extractVideoID(from: "https://youtu.be/dQw4w9WgXcQ?t=42")
        #expect(id == "dQw4w9WgXcQ")
    }

    @Test("Short http youtu.be URL")
    func shortHTTPURL() {
        let id = YouTubeExtractor.extractVideoID(from: "http://youtu.be/dQw4w9WgXcQ")
        #expect(id == "dQw4w9WgXcQ")
    }

    // Raw video IDs
    @Test("Bare 11-character video ID")
    func bareVideoID() {
        let id = YouTubeExtractor.extractVideoID(from: "dQw4w9WgXcQ")
        #expect(id == "dQw4w9WgXcQ")
    }

    @Test("Video ID with underscores and hyphens")
    func videoIDWithSpecialChars() {
        let id = YouTubeExtractor.extractVideoID(from: "a-b_c123456")
        #expect(id == "a-b_c123456")
    }

    // Leading/trailing whitespace
    @Test("URL with leading and trailing whitespace")
    func urlWithWhitespace() {
        let id = YouTubeExtractor.extractVideoID(from: "  https://www.youtube.com/watch?v=dQw4w9WgXcQ  ")
        #expect(id == "dQw4w9WgXcQ")
    }

    @Test("Bare ID with surrounding whitespace")
    func bareIDWithWhitespace() {
        let id = YouTubeExtractor.extractVideoID(from: "\tdQw4w9WgXcQ\n")
        #expect(id == "dQw4w9WgXcQ")
    }

    // Embed URLs (no ?v= query param)
    @Test("Embed URL returns nil")
    func embedURL() {
        let id = YouTubeExtractor.extractVideoID(from: "https://www.youtube.com/embed/dQw4w9WgXcQ")
        #expect(id == nil)
    }

    // Invalid inputs
    @Test("Empty string returns nil")
    func emptyString() {
        let id = YouTubeExtractor.extractVideoID(from: "")
        #expect(id == nil)
    }

    @Test("Whitespace-only string returns nil")
    func whitespaceOnly() {
        let id = YouTubeExtractor.extractVideoID(from: "   ")
        #expect(id == nil)
    }

    @Test("Random text returns nil")
    func randomText() {
        let id = YouTubeExtractor.extractVideoID(from: "not a url at all")
        #expect(id == nil)
    }

    @Test("Too-short ID returns nil")
    func tooShortID() {
        let id = YouTubeExtractor.extractVideoID(from: "short")
        #expect(id == nil)
    }

    @Test("Too-long bare ID returns nil")
    func tooLongID() {
        let id = YouTubeExtractor.extractVideoID(from: "dQw4w9WgXcQextra")
        #expect(id == nil)
    }

    @Test("ID with invalid character returns nil")
    func invalidCharacterInID() {
        let id = YouTubeExtractor.extractVideoID(from: "dQw4w9WgXc!")
        #expect(id == nil)
    }

    @Test("Vimeo URL returns nil")
    func vimeoURL() {
        let id = YouTubeExtractor.extractVideoID(from: "https://vimeo.com/123456789")
        #expect(id == nil)
    }

    @Test("URL missing v= param returns nil")
    func urlMissingVParam() {
        let id = YouTubeExtractor.extractVideoID(from: "https://www.youtube.com/watch?list=PLabcdefghijk")
        #expect(id == nil)
    }

    @Test("Watch URL with 10-character v value returns nil")
    func shortVParam() {
        let id = YouTubeExtractor.extractVideoID(from: "https://www.youtube.com/watch?v=dQw4w9WgX")
        #expect(id == nil)
    }

    @Test("Watch URL with 12-character v value returns nil")
    func longVParam() {
        let id = YouTubeExtractor.extractVideoID(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQQ")
        #expect(id == nil)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DownloadStatus
// ─────────────────────────────────────────────────────────────────────────────

@Suite("DownloadStatus")
struct DownloadStatusTests {

    @Test("idle is not active")
    func idleNotActive() {
        #expect(DownloadStatus.idle.isActive == false)
    }

    @Test("extracting is active")
    func extractingIsActive() {
        #expect(DownloadStatus.extracting.isActive == true)
    }

    @Test("downloading is active")
    func downloadingIsActive() {
        #expect(DownloadStatus.downloading(progress: 0.5).isActive == true)
    }

    @Test("converting is active")
    func convertingIsActive() {
        #expect(DownloadStatus.converting.isActive == true)
    }

    @Test("completed is not active")
    func completedNotActive() {
        let url = URL(string: "file:///tmp/audio.m4a")!
        #expect(DownloadStatus.completed(fileURL: url).isActive == false)
    }

    @Test("failed is not active")
    func failedNotActive() {
        #expect(DownloadStatus.failed(message: "err").isActive == false)
    }

    @Test("Equality: idle == idle")
    func equalityIdle() {
        #expect(DownloadStatus.idle == DownloadStatus.idle)
    }

    @Test("Equality: extracting == extracting")
    func equalityExtracting() {
        #expect(DownloadStatus.extracting == DownloadStatus.extracting)
    }

    @Test("Inequality: idle != extracting")
    func inequalityDifferentCases() {
        #expect(DownloadStatus.idle != DownloadStatus.extracting)
    }

    @Test("Equality: downloading with same progress")
    func equalityDownloadingSameProgress() {
        #expect(DownloadStatus.downloading(progress: 0.5) == DownloadStatus.downloading(progress: 0.5))
    }

    @Test("Inequality: downloading with different progress")
    func inequalityDownloadingDiffProgress() {
        #expect(DownloadStatus.downloading(progress: 0.4) != DownloadStatus.downloading(progress: 0.6))
    }

    @Test("Equality: failed with same message")
    func equalityFailedSameMessage() {
        #expect(DownloadStatus.failed(message: "oops") == DownloadStatus.failed(message: "oops"))
    }

    @Test("Inequality: failed with different messages")
    func inequalityFailedDiffMessage() {
        #expect(DownloadStatus.failed(message: "a") != DownloadStatus.failed(message: "b"))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DownloadItem
// ─────────────────────────────────────────────────────────────────────────────

@Suite("DownloadItem")
struct DownloadItemTests {

    @Test("Initialises with given videoID")
    func initVideoID() {
        let item = DownloadItem(videoID: "dQw4w9WgXcQ")
        #expect(item.videoID == "dQw4w9WgXcQ")
    }

    @Test("Default title falls back to videoID")
    func defaultTitleFallback() {
        let item = DownloadItem(videoID: "dQw4w9WgXcQ")
        #expect(item.title == "dQw4w9WgXcQ")
    }

    @Test("Custom title is used when provided")
    func customTitle() {
        let item = DownloadItem(videoID: "dQw4w9WgXcQ", title: "Never Gonna Give You Up")
        #expect(item.title == "Never Gonna Give You Up")
    }

    @Test("Empty title falls back to videoID")
    func emptyTitleFallback() {
        let item = DownloadItem(videoID: "dQw4w9WgXcQ", title: "")
        #expect(item.title == "dQw4w9WgXcQ")
    }

    @Test("Default status is idle")
    func defaultStatusIsIdle() {
        let item = DownloadItem(videoID: "dQw4w9WgXcQ")
        #expect(item.status == .idle)
    }

    @Test("Each item gets a unique UUID")
    func uniqueUUIDs() {
        let a = DownloadItem(videoID: "aaaaaaaaaaa")
        let b = DownloadItem(videoID: "aaaaaaaaaaa")
        #expect(a.id != b.id)
    }

    @Test("thumbnailURL is set when provided")
    func thumbnailURLSet() {
        let thumb = URL(string: "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
        let item = DownloadItem(videoID: "dQw4w9WgXcQ", thumbnailURL: thumb)
        #expect(item.thumbnailURL == thumb)
    }

    @Test("addedAt is close to now")
    func addedAtIsNow() {
        let before = Date()
        let item = DownloadItem(videoID: "dQw4w9WgXcQ")
        let after = Date()
        #expect(item.addedAt >= before)
        #expect(item.addedAt <= after)
    }

    @Test("Status can be mutated")
    func statusMutation() {
        var item = DownloadItem(videoID: "dQw4w9WgXcQ")
        item.status = .extracting
        #expect(item.status == .extracting)
        item.status = .downloading(progress: 0.3)
        #expect(item.status == .downloading(progress: 0.3))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ExtractionError
// ─────────────────────────────────────────────────────────────────────────────

@Suite("ExtractionError")
struct ExtractionErrorTests {

    @Test("invalidURL description")
    func invalidURL() {
        #expect(ExtractionError.invalidURL.errorDescription == "Invalid YouTube URL")
    }

    @Test("noAudioStream description")
    func noAudioStream() {
        #expect(ExtractionError.noAudioStream.errorDescription?.contains("No audio stream") == true)
    }

    @Test("noStreamURL description")
    func noStreamURL() {
        #expect(ExtractionError.noStreamURL.errorDescription?.contains("Could not retrieve stream URL") == true)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ConversionError
// ─────────────────────────────────────────────────────────────────────────────

@Suite("ConversionError")
struct ConversionErrorTests {

    @Test("downloadFailed with non-zero code includes HTTP code")
    func downloadFailedWithCode() {
        #expect(ConversionError.downloadFailed(statusCode: 403).errorDescription?.contains("403") == true)
    }

    @Test("downloadFailed with statusCode 0 gives generic message")
    func downloadFailedNoCode() {
        let desc = ConversionError.downloadFailed(statusCode: 0).errorDescription
        #expect(desc?.contains("Failed to download audio stream") == true)
        #expect(desc?.contains("HTTP") == false)
    }

    @Test("conversionFailed description")
    func conversionFailed() {
        #expect(ConversionError.conversionFailed.errorDescription == "Failed to convert audio format")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PipedStreamResponse JSON decoding
// ─────────────────────────────────────────────────────────────────────────────

@Suite("PipedStreamResponse JSON decoding")
struct PipedStreamResponseTests {

    @Test("Decodes full response correctly")
    func decodesFullResponse() throws {
        let json = """
        {
            "title": "Test Song",
            "thumbnailUrl": "https://img.example.com/thumb.jpg",
            "duration": 215,
            "audioStreams": [
                {
                    "url": "https://audio.example.com/stream",
                    "format": "M4A",
                    "quality": "medium",
                    "mimeType": "audio/mp4",
                    "bitrate": 128000,
                    "contentLength": 3456789
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(PipedStreamResponse.self, from: data)

        #expect(response.title == "Test Song")
        #expect(response.duration == 215)
        #expect(response.audioStreams?.count == 1)
        #expect(response.audioStreams?[0].mimeType == "audio/mp4")
        #expect(response.audioStreams?[0].bitrate == 128_000)
    }

    @Test("Tolerates missing optional fields")
    func toleratesMissingOptionals() throws {
        let json = """
        {
            "audioStreams": []
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(PipedStreamResponse.self, from: data)
        #expect(response.title == nil)
        #expect(response.duration == nil)
        #expect(response.audioStreams?.isEmpty == true)
    }

    @Test("Decodes multiple audio streams")
    func decodesMultipleStreams() throws {
        let json = """
        {
            "title": "Song",
            "audioStreams": [
                { "url": "https://a1.example.com", "mimeType": "audio/mp4",  "bitrate": 128000 },
                { "url": "https://a2.example.com", "mimeType": "audio/webm", "bitrate": 160000 }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(PipedStreamResponse.self, from: data)
        #expect(response.audioStreams?.count == 2)
    }
}

