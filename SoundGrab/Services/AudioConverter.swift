import Foundation
import AVFoundation

// Minimum number of bytes a valid audio download must contain.
private let minimumValidDownloadSize: Int64 = 1_000

private nonisolated final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let onProgress: @Sendable (Double) -> Void
    private let completion: @Sendable (Result<Void, Error>) -> Void
    var retainedSession: URLSession?

    init(
        destination: URL,
        onProgress: @escaping @Sendable (Double) -> Void,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        self.destination = destination
        self.onProgress = onProgress
        self.completion = completion
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? 0
            guard size > minimumValidDownloadSize else {
                throw ConversionError.downloadFailed(statusCode: 0)
            }
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
        retainedSession = nil
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(progress)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                retainedSession = nil
                return
            }
            completion(.failure(error))
        }
        retainedSession = nil
    }
}

private nonisolated final class ContinuationGuard: @unchecked Sendable {
    private var resumed = false
    private let lock = NSLock()

    func resume(_ continuation: CheckedContinuation<Void, Error>, with result: Result<Void, Error>) {
        lock.lock()
        let shouldResume = !resumed
        if shouldResume { resumed = true }
        lock.unlock()
        if shouldResume {
            continuation.resume(with: result)
        }
    }
}

actor AudioConverter {
    static let shared = AudioConverter()

    func downloadAndConvert(
        streamURL: URL,
        title: String,
        fileExtension: String,
        onProgress: @Sendable @MainActor (Double) -> Void
    ) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let sanitizedTitle = sanitizeFilename(title)
        let downloadedFile = tempDir.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
        let outputFile = documentsDirectory().appendingPathComponent("\(sanitizedTitle).m4a")

        defer {
            try? FileManager.default.removeItem(at: downloadedFile)
        }

        try await downloadFile(from: streamURL, to: downloadedFile, onProgress: onProgress)

        await onProgress(0.7)

        if FileManager.default.fileExists(atPath: outputFile.path) {
            try FileManager.default.removeItem(at: outputFile)
        }

        if fileExtension == "m4a" {
            try FileManager.default.copyItem(at: downloadedFile, to: outputFile)
        } else {
            try await convertToM4A(input: downloadedFile, output: outputFile)
        }

        await onProgress(1.0)
        return outputFile
    }

    private func downloadFile(
        from url: URL,
        to destination: URL,
        onProgress: @Sendable @MainActor (Double) -> Void
    ) async throws {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true

        var request = URLRequest(url: url)
        request.setValue(
            "com.google.ios.youtube/20.03.02 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X; en_US)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 120

        let maxRetries = 3
        var lastError: Error = ConversionError.downloadFailed(statusCode: 0)

        for attempt in 0..<maxRetries {
            do {
                if attempt > 0 {
                    try await Task.sleep(for: .seconds(Double(attempt) * 2.0))
                }

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let continuationGuard = ContinuationGuard()

                    let delegate = DownloadProgressDelegate(
                        destination: destination,
                        onProgress: { progress in
                            let normalized = min(0.49, progress * 0.5)
                            Task { @MainActor in
                                onProgress(normalized)
                            }
                        },
                        completion: { result in
                            continuationGuard.resume(continuation, with: result)
                        }
                    )

                    let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
                    delegate.retainedSession = session
                    let task = session.downloadTask(with: request)
                    task.resume()
                }

                await onProgress(0.5)
                return
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError
    }

    private func convertToM4A(
        input: URL,
        output: URL
    ) async throws {
        let asset = AVURLAsset(url: input)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ConversionError.conversionFailed
        }

        exportSession.outputURL = output
        exportSession.outputFileType = .m4a

        await exportSession.export()

        if let error = exportSession.error {
            throw error
        }

        guard exportSession.status == .completed else {
            throw ConversionError.conversionFailed
        }
    }

    func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let sanitized = name.components(separatedBy: invalidChars).joined(separator: "_")
        let trimmed = String(sanitized.prefix(100))
        return trimmed.isEmpty ? "audio" : trimmed
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

nonisolated enum ConversionError: LocalizedError, Sendable {
    case downloadFailed(statusCode: Int)
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let code):
            if code > 0 {
                return "Failed to download audio (HTTP \(code))"
            }
            return "Failed to download audio stream"
        case .conversionFailed: return "Failed to convert audio format"
        }
    }
}
