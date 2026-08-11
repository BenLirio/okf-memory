import Foundation

enum APIError: LocalizedError {
    case http(Int, String)
    var errorDescription: String? {
        if case .http(let code, let body) = self { return "Server error \(code): \(body.prefix(200))" }
        return "Unknown error"
    }
}

struct API {
    static let shared = API()
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 180
        return URLSession(configuration: cfg)
    }()

    private func request(_ path: String, method: String = "GET") -> URLRequest {
        var r = URLRequest(url: Secrets.serverURL.appending(path: path))
        r.httpMethod = method
        r.setValue("Bearer \(Secrets.apiToken)", forHTTPHeaderField: "Authorization")
        return r
    }

    private func run<T: Decodable>(_ req: URLRequest, as type: T.Type) async throws -> T {
        let (data, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw APIError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func memories() async throws -> [MemorySummary] {
        try await run(request("/api/memories"), as: [MemorySummary].self)
    }

    func memory(path: String) async throws -> MemoryDetail {
        try await run(request("/api/memories/\(path)"), as: MemoryDetail.self)
    }

    func notifications() async throws -> [NotificationItem] {
        try await run(request("/api/notifications"), as: [NotificationItem].self)
    }

    func capture(fileData: Data?, filename: String?, mime: String?, text: String?) async throws -> CaptureResponse {
        try await run(multipart(path: "/api/capture", fileData: fileData, filename: filename,
                                mime: mime, text: text), as: CaptureResponse.self)
    }

    func query(audioData: Data?, text: String?) async throws -> QueryResponse {
        try await run(multipart(path: "/api/query", fileData: audioData, filename: "question.m4a",
                                mime: "audio/m4a", text: text), as: QueryResponse.self)
    }

    private func multipart(path: String, fileData: Data?, filename: String?, mime: String?, text: String?) -> URLRequest {
        var req = request(path, method: "POST")
        let boundary = "recall-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func field(_ s: String) { body.append(s.data(using: .utf8)!) }
        if let data = fileData {
            field("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(filename ?? "file")\"\r\n")
            field("Content-Type: \(mime ?? "application/octet-stream")\r\n\r\n")
            body.append(data)
            field("\r\n")
        }
        if let text, !text.isEmpty {
            field("--\(boundary)\r\nContent-Disposition: form-data; name=\"text\"\r\n\r\n\(text)\r\n")
        }
        field("--\(boundary)--\r\n")
        req.httpBody = body
        return req
    }
}
