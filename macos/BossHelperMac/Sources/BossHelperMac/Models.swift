import Foundation

struct HealthResponse: Codable {
    let status: String
    let version: String
    let pid: Int
}

struct MetricsResponse: Codable {
    let date: String
    let total: Int
    let success: Int
    let danger: Int
    let warning: Int
    let deliveryLimit: Int?
    let elapsedSeconds: Int
    let firstEventAt: String?
    let lastEventAt: String?
}

struct CrawlLogEntry: Codable {
    let level: String
    let message: String
}

struct CrawlStatusResponse: Codable {
    let state: String
    let runId: Int?
    let currentKeyword: String
    let currentPage: Int
    let scrapedCount: Int
    let errorCount: Int
    let lastMessage: String
    let startedAt: String?
    let finishedAt: String?
    let logTail: [CrawlLogEntry]
}

struct ImportResponse: Codable {
    let code: Int
    let imported: Int
    let skipped: Int
    let files: Int
}

struct ShutdownResponse: Codable {
    let code: Int
    let message: String
}

enum BackendLogCategory: String, CaseIterable, Identifiable {
    case delivery
    case polling
    case system
    case error

    var id: String { rawValue }

    var title: String {
        switch self {
        case .delivery: return "投递"
        case .polling: return "轮询"
        case .system: return "系统"
        case .error: return "错误"
        }
    }
}

struct BackendLogEntry: Identifiable {
    let id = UUID()
    let category: BackendLogCategory
    let text: String
    let timestamp: Date
}
