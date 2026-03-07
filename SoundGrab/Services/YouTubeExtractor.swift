import Foundation

nonisolated struct ExtractedAudio: Sendable {
    let title: String
    let streamURL: URL
    let fileExtension: String
    let thumbnailURL: URL?
    let duration: String?
}

nonisolated struct PageTokens: Sendable {
    let visitorData: String
    let signatureTimestamp: Int?
    let title: String?
    let lengthSeconds: String?
    let thumbnailURL: URL?
}

nonisolated struct InnertubeAudioFormat: Sendable {
    let url: String
    let mimeType: String
    let bitrate: Int
    let itag: Int
}

nonisolated struct PipedStreamResponse: Codable, Sendable {
    let title: String?
    let thumbnailUrl: String?
    let duration: Int?
    let audioStreams: [PipedAudioStream]?
}

nonisolated struct PipedAudioStream: Codable, Sendable {
    let url: String?
    let format: String?
    let quality: String?
    let mimeType: String?
    let bitrate: Int?
    let contentLength: Int?
}

struct YouTubeExtractor {

    private static let pipedInstances = [
        "https://pipedapi.kavin.rocks",
        "https://pipedapi.adminforge.de",
        "https://pipedapi.r4fo.com",
        "https://pipedapi.leptons.xyz"
    ]

    static func extractVideoID(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed) {
            if url.host?.contains("youtu.be") == true {
                let id = url.lastPathComponent
                return id.count == 11 ? id : nil
            }
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let vParam = queryItems.first(where: { $0.name == "v" })?.value {
                return vParam.count == 11 ? vParam : nil
            }
        }

        if trimmed.count == 11, trimmed.range(of: "^[a-zA-Z0-9_-]{11}$", options: .regularExpression) != nil {
            return trimmed
        }

        return nil
    }

    static func extractAudio(videoID: String) async throws -> ExtractedAudio {
        if let result = try? await extractViaWebScrapeAndClients(videoID: videoID) {
            return result
        }

        for instance in pipedInstances {
            if let result = try? await fetchFromPiped(instance, videoID: videoID) {
                return result
            }
        }

        throw ExtractionError.noAudioStream
    }

    private static func extractViaWebScrapeAndClients(videoID: String) async throws -> ExtractedAudio {
        let tokens = try await fetchPageTokens(videoID: videoID)

        // Try IOS client first – returns direct-downloadable URLs from iOS
        let audioFormats: [InnertubeAudioFormat]
        if let iosFormats = try? await fetchViaIOSClient(videoID: videoID, tokens: tokens),
           !iosFormats.isEmpty {
            audioFormats = iosFormats
        } else {
            audioFormats = try await fetchViaAndroidVR(videoID: videoID, tokens: tokens)
        }

        return try buildExtractedAudio(from: audioFormats, tokens: tokens, videoID: videoID)
    }

    /// Selects the best audio format: prefers audio/mp4, then highest bitrate.
    static func selectBestFormat(from formats: [InnertubeAudioFormat]) -> InnertubeAudioFormat? {
        formats
            .sorted { a, b in
                let scoreA = a.bitrate + (a.mimeType.contains("audio/mp4") ? 1_000_000 : 0)
                let scoreB = b.bitrate + (b.mimeType.contains("audio/mp4") ? 1_000_000 : 0)
                return scoreA > scoreB
            }
            .first
    }

    private static func buildExtractedAudio(
        from audioFormats: [InnertubeAudioFormat],
        tokens: PageTokens,
        videoID: String
    ) throws -> ExtractedAudio {

        guard let bestFormat = selectBestFormat(from: audioFormats),
              let streamURL = URL(string: bestFormat.url) else {
            throw ExtractionError.noStreamURL
        }

        let title = tokens.title ?? videoID
        let ext = bestFormat.mimeType.contains("audio/mp4") ? "m4a" : "webm"

        return ExtractedAudio(
            title: title,
            streamURL: streamURL,
            fileExtension: ext,
            thumbnailURL: tokens.thumbnailURL ?? URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg"),
            duration: formatDuration(tokens.lengthSeconds)
        )
    }

    private static func fetchPageTokens(videoID: String) async throws -> PageTokens {
        guard let pageURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)") else {
            throw ExtractionError.invalidURL
        }

        var request = URLRequest(url: pageURL)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("CONSENT=YES+1", forHTTPHeaderField: "Cookie")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ExtractionError.noAudioStream
        }

        var visitorData = ""
        if let range = html.range(of: "\"visitorData\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            let match = html[range]
            if let valueRange = match.range(of: "\"([^\"]+)\"$", options: .regularExpression) {
                visitorData = String(match[valueRange]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }

        var signatureTimestamp: Int?
        if let range = html.range(of: "\"jsUrl\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            let match = html[range]
            if let urlRange = match.range(of: "\"([^\"]+)\"$", options: .regularExpression) {
                let jsPath = String(match[urlRange]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                signatureTimestamp = await fetchSignatureTimestamp(jsPath: jsPath)
            }
        }

        var title: String?
        var lengthSeconds: String?
        var thumbnailURL: URL?

        if let jsonRange = html.range(of: "var ytInitialPlayerResponse\\s*=\\s*(\\{.+?\\});\\s*var", options: .regularExpression) {
            let jsonMatch = html[jsonRange]
            if let braceStart = jsonMatch.firstIndex(of: "{"),
               let braceEnd = jsonMatch.range(of: "};")?.lowerBound {
                let jsonStr = String(jsonMatch[braceStart...braceEnd])
                if let jsonData = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    if let vd = json["videoDetails"] as? [String: Any] {
                        title = vd["title"] as? String
                        lengthSeconds = vd["lengthSeconds"] as? String
                    }
                }
            }
        }

        if title == nil {
            if let range = html.range(of: "<title>([^<]+)</title>", options: .regularExpression) {
                let match = html[range]
                if let start = match.range(of: ">")?.upperBound,
                   let end = match.range(of: "</")?.lowerBound {
                    let raw = String(match[start..<end])
                    title = raw.replacingOccurrences(of: " - YouTube", with: "").trimmingCharacters(in: .whitespaces)
                }
            }
        }

        thumbnailURL = URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")

        return PageTokens(
            visitorData: visitorData,
            signatureTimestamp: signatureTimestamp,
            title: title,
            lengthSeconds: lengthSeconds,
            thumbnailURL: thumbnailURL
        )
    }

    private static func fetchSignatureTimestamp(jsPath: String) async -> Int? {
        let fullURL: String
        if jsPath.hasPrefix("http") {
            fullURL = jsPath
        } else {
            fullURL = "https://www.youtube.com\(jsPath)"
        }

        guard let url = URL(string: fullURL) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let js = String(data: data, encoding: .utf8) else {
            return nil
        }

        if let range = js.range(of: "signatureTimestamp\\s*[=:]\\s*(\\d+)", options: .regularExpression) {
            let match = js[range]
            if let numRange = match.range(of: "\\d+", options: .regularExpression) {
                return Int(match[numRange])
            }
        }

        return nil
    }

    private static func fetchViaAndroidVR(videoID: String, tokens: PageTokens) async throws -> [InnertubeAudioFormat] {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            throw ExtractionError.invalidURL
        }

        var clientContext: [String: Any] = [
            "clientName": "ANDROID_VR",
            "clientVersion": "1.63.20",
            "deviceMake": "Oculus",
            "deviceModel": "Quest 3",
            "androidSdkVersion": 32,
            "osName": "Android",
            "osVersion": "12L",
            "hl": "en",
            "gl": "US"
        ]

        if !tokens.visitorData.isEmpty {
            clientContext["visitorData"] = tokens.visitorData
        }

        var body: [String: Any] = [
            "videoId": videoID,
            "context": [
                "client": clientContext
            ],
            "contentCheckOk": true,
            "racyCheckOk": true
        ]

        if let sts = tokens.signatureTimestamp {
            body["playbackContext"] = [
                "contentPlaybackContext": [
                    "signatureTimestamp": sts
                ]
            ]
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("com.google.android.apps.youtube.vr.oculus/1.63.20 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip", forHTTPHeaderField: "User-Agent")

        if !tokens.visitorData.isEmpty {
            let decoded = tokens.visitorData.removingPercentEncoding ?? tokens.visitorData
            request.setValue(decoded, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }

        let (data, _) = try await URLSession.shared.data(for: request)

        return try parseAudioFormats(from: data)
    }

    private static func fetchViaIOSClient(videoID: String, tokens: PageTokens) async throws -> [InnertubeAudioFormat] {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            throw ExtractionError.invalidURL
        }

        var clientContext: [String: Any] = [
            "clientName": "IOS",
            "clientVersion": "20.03.02",
            "deviceMake": "Apple",
            "deviceModel": "iPhone16,2",
            "osName": "iPhone",
            "osVersion": "18.3.2",
            "hl": "en",
            "gl": "US"
        ]

        if !tokens.visitorData.isEmpty {
            clientContext["visitorData"] = tokens.visitorData
        }

        var body: [String: Any] = [
            "videoId": videoID,
            "context": ["client": clientContext],
            "contentCheckOk": true,
            "racyCheckOk": true
        ]

        if let sts = tokens.signatureTimestamp {
            body["playbackContext"] = [
                "contentPlaybackContext": [
                    "signatureTimestamp": sts
                ]
            ]
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "com.google.ios.youtube/20.03.02 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X; en_US)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("5", forHTTPHeaderField: "X-Youtube-Client-Name")
        request.setValue("20.03.02", forHTTPHeaderField: "X-Youtube-Client-Version")

        if !tokens.visitorData.isEmpty {
            let decoded = tokens.visitorData.removingPercentEncoding ?? tokens.visitorData
            request.setValue(decoded, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }

        let (data, _) = try await URLSession.shared.data(for: request)

        return try parseAudioFormats(from: data)
    }

    static func parseAudioFormats(from data: Data) throws -> [InnertubeAudioFormat] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExtractionError.noAudioStream
        }

        if let status = json["playabilityStatus"] as? [String: Any],
           let statusStr = status["status"] as? String,
           statusStr != "OK" {
            throw ExtractionError.noAudioStream
        }

        guard let streamingData = json["streamingData"] as? [String: Any] else {
            throw ExtractionError.noAudioStream
        }

        let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] ?? []
        let formats = streamingData["formats"] as? [[String: Any]] ?? []
        let allFormats = adaptiveFormats + formats

        var audioFormats: [InnertubeAudioFormat] = []

        for format in allFormats {
            let mime = format["mimeType"] as? String ?? ""
            guard mime.hasPrefix("audio/") else { continue }
            guard let urlStr = format["url"] as? String, !urlStr.isEmpty else { continue }

            let bitrate = format["bitrate"] as? Int ?? 0
            let itag = format["itag"] as? Int ?? 0

            audioFormats.append(InnertubeAudioFormat(
                url: urlStr,
                mimeType: mime,
                bitrate: bitrate,
                itag: itag
            ))
        }

        guard !audioFormats.isEmpty else {
            throw ExtractionError.noAudioStream
        }

        return audioFormats
    }

    static func formatDuration(_ secondsString: String?) -> String? {
        guard let str = secondsString, let dur = Int(str), dur > 0 else { return nil }
        let hours = dur / 3600
        let minutes = (dur % 3600) / 60
        let secs = dur % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private static func fetchFromPiped(_ baseURL: String, videoID: String) async throws -> ExtractedAudio {
        guard let url = URL(string: "\(baseURL)/streams/\(videoID)") else {
            throw ExtractionError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ExtractionError.noAudioStream
        }

        guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
              contentType.contains("json") else {
            throw ExtractionError.noAudioStream
        }

        let streamResponse = try JSONDecoder().decode(PipedStreamResponse.self, from: data)

        guard let audioStreams = streamResponse.audioStreams, !audioStreams.isEmpty else {
            throw ExtractionError.noAudioStream
        }

        let preferredStream = audioStreams
            .filter { $0.mimeType?.contains("audio/mp4") == true || $0.mimeType?.contains("audio/webm") == true }
            .filter { $0.url != nil && !($0.url?.isEmpty ?? true) }
            .sorted { ($0.bitrate ?? 0) > ($1.bitrate ?? 0) }
            .first ?? audioStreams.first(where: { $0.url != nil })

        guard let stream = preferredStream,
              let streamURLString = stream.url,
              let streamURL = URL(string: streamURLString) else {
            throw ExtractionError.noStreamURL
        }

        let title = streamResponse.title ?? videoID
        let isM4A = stream.mimeType?.contains("audio/mp4") == true
        let fileExtension = isM4A ? "m4a" : "webm"

        let thumbnailURL: URL? = {
            if let urlStr = streamResponse.thumbnailUrl {
                return URL(string: urlStr)
            }
            return URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")
        }()

        let durationString: String? = {
            guard let dur = streamResponse.duration, dur > 0 else { return nil }
            let hours = dur / 3600
            let minutes = (dur % 3600) / 60
            let secs = dur % 60
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, secs)
            }
            return String(format: "%d:%02d", minutes, secs)
        }()

        return ExtractedAudio(
            title: title,
            streamURL: streamURL,
            fileExtension: fileExtension,
            thumbnailURL: thumbnailURL,
            duration: durationString
        )
    }
}

nonisolated enum ExtractionError: LocalizedError, Sendable {
    case invalidURL
    case noAudioStream
    case noStreamURL

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid YouTube URL"
        case .noAudioStream: return "No audio stream found for this video. Please try again later."
        case .noStreamURL: return "Could not retrieve stream URL"
        }
    }
}
