import Foundation

// MARK: - CommandEncoder

/// Pure-value-type JSON encoder/decoder for CommandMessage.
struct CommandEncoder: Sendable {

    private static let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()

    private static let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    func encode(_ message: CommandMessage) throws -> Data {
        try CommandEncoder.encoder.encode(message)
    }

    func decode(_ data: Data) throws -> CommandMessage {
        try CommandEncoder.decoder.decode(CommandMessage.self, from: data)
    }
}