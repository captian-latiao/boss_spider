import Foundation

enum BackendClientError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "后端返回了无法解析的数据"
        }
    }
}

struct BackendClient {
    let baseURL: URL

    init(baseURL: URL = URL(string: "http://127.0.0.1:5005")!) {
        self.baseURL = baseURL
    }

    func health() async throws -> HealthResponse {
        try await get("/health")
    }

    func metricsToday() async throws -> MetricsResponse {
        try await get("/api/metrics/today")
    }

    func crawlStatus() async throws -> CrawlStatusResponse {
        try await get("/api/crawl/status")
    }

    func startCrawl() async throws -> CrawlStatusResponse {
        try await post("/api/crawl/start", body: EmptyBody())
    }

    func stopCrawl() async throws -> CrawlStatusResponse {
        try await post("/api/crawl/stop", body: EmptyBody())
    }

    func importPaths(_ paths: [String]) async throws -> ImportResponse {
        try await post("/api/import", body: ImportRequest(paths: paths))
    }

    func shutdown() async throws -> ShutdownResponse {
        try await post("/api/shutdown", body: EmptyBody())
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "GET"
        return try await send(request)
    }

    private func post<Body: Encodable, T: Decodable>(
        _ path: String,
        body: Body
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw BackendClientError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}

private struct EmptyBody: Encodable {}

private struct ImportRequest: Encodable {
    let paths: [String]
}
