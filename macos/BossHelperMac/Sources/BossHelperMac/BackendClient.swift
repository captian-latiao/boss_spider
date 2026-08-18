import Foundation

enum BackendClientError: LocalizedError {
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "后端返回了无法解析的数据"
        case .serverError(let msg):
            return msg
        }
    }
}

struct BackendClient {
    let baseURL: URL

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration)
    }()

    init(baseURL: URL = URL(string: "http://127.0.0.1:5005")!) {
        self.baseURL = baseURL
    }

    func health() async throws -> HealthResponse {
        try await get("/health")
    }

    func metricsToday() async throws -> MetricsResponse {
        try await get("/api/metrics/today")
    }

    func recentEvents(limit: Int = 50) async throws -> [DeliveryEventItem] {
        try await get("/api/events/recent?limit=\(limit)")
    }

    func jobs(limit: Int = 100, status: String? = nil, keyword: String? = nil) async throws -> [JobItem] {
        var queryItems: [String] = ["limit=\(limit)"]
        if let status, !status.isEmpty, status != "all" {
            queryItems.append("status=\(status.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? status)")
        }
        if let keyword, !keyword.isEmpty {
            queryItems.append("keyword=\(keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword)")
        }
        let queryString = queryItems.joined(separator: "&")
        return try await get("/api/jobs?\(queryString)")
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

    func saveDeliveryLimit(_ limit: Int) async throws {
        _ = try await post("/api/config/delivery_limit", body: DeliveryLimitRequest(limit: limit)) as ImportResponse
    }

    func shutdown() async throws -> ShutdownResponse {
        try await post("/api/shutdown", body: EmptyBody())
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw BackendClientError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await send(request)
    }

    private func post<Body: Encodable, T: Decodable>(
        _ path: String,
        body: Body
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw BackendClientError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await Self.session.data(for: request)
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

private struct DeliveryLimitRequest: Encodable {
    let limit: Int
}
