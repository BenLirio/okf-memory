import Foundation

/// Arbitrary JSON — OKF frontmatter is open vocabulary, so it can't be a fixed struct.
enum JSONValue: Codable, Hashable {
    case string(String), number(Double), bool(Bool), null
    case array([JSONValue]), object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
}

struct MemorySummary: Codable, Identifiable, Hashable {
    var path: String
    var type: String?
    var title: String
    var description: String
    var tags: [String]
    var status: String
    var generated_at: String
    var notification_count: Int
    var id: String { path }
}

struct MemoryDetail: Codable, Hashable {
    var path: String
    var frontmatter: [String: JSONValue]
    var body: String
}

struct NotificationItem: Codable, Identifiable, Hashable {
    var id: String
    var at: String
    var title: String
    var body: String
    var memory_path: String

    var date: Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: at) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: at)
    }
}

struct CaptureResponse: Codable {
    var written: [String]
    var transcript: String?
    var log_entry: String
    var memories: [MemoryDetail]
    var notifications: [NotificationItem]
}

struct QueryResponse: Codable {
    var question: String
    var answer: String
    var audio_mime: String
    var audio_b64: String
}
