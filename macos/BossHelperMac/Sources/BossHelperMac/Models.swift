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
    let activeSeconds: Int?
    let pauseCount: Int?
    let pauseSeconds: Int?
    let speedPerHour: Double?
}

struct DailySpeedItem: Codable, Identifiable {
    let date: String
    let total: Int
    let activeSeconds: Int
    let pauseCount: Int
    let speedPerHour: Double

    var id: String { date }
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

struct DeliveryEventItem: Codable, Identifiable {
    let id: Int
    let jobId: String
    let deliverStatus: String
    let filterReason: String?
    let filterDetail: String?
    let eventTime: String
    let jobName: String?
    let jobCompany: String?
    let jobArea: String?
    let salaryRange: String?
    let bossName: String?
    let bossTitle: String?

    var isSuccess: Bool {
        let s = deliverStatus.lowercased()
        return s == "success" || s == "delivered"
    }

    var isFilter: Bool {
        let s = deliverStatus.lowercased()
        return s == "warning" || s == "filter" || s == "filtered"
    }

    var isDanger: Bool {
        let s = deliverStatus.lowercased()
        return s == "danger" || s == "error" || s == "failed"
    }

    var formattedTime: String {
        if let timePart = eventTime.split(separator: "T").last {
            return String(timePart.prefix(8))
        }
        if eventTime.count >= 8 {
            return String(eventTime.suffix(8))
        }
        return eventTime
    }
}

struct JobItem: Codable, Identifiable {
    var id: String { jobId }
    let jobId: String
    let jobName: String?
    let jobCompany: String?
    let jobArea: String?
    let jobIndustry: String?
    let jobFinance: String?
    let jobScale: String?
    let salaryRange: String?
    let jobExperience: String?
    let jobEducation: String?
    let deliverStatus: String?
    let filterReason: String?
    let filterDetail: String?
    let bossName: String?
    let bossTitle: String?
    let bossActive: String?
    let postDescription: String?
    let createTime: String?
    let ingestedAt: String?

    var isSuccess: Bool {
        let s = (deliverStatus ?? "").lowercased()
        return s == "success" || s == "delivered"
    }

    var isFilter: Bool {
        let s = (deliverStatus ?? "").lowercased()
        return s == "warning" || s == "filter" || s == "filtered"
    }

    var isDanger: Bool {
        let s = (deliverStatus ?? "").lowercased()
        return s == "danger" || s == "error" || s == "failed"
    }

    var displayStatus: String {
        if isSuccess { return "已投递" }
        if isFilter { return "已过滤" }
        if isDanger { return "投递异常" }
        return "待处理"
    }

    var matchedKeyword: String? {
        let combined = "\(filterReason ?? "") \(filterDetail ?? "")"
        if let start = combined.firstIndex(of: "["),
           let end = combined.firstIndex(of: "]"),
           start < end {
            let kw = String(combined[combined.index(after: start)..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !kw.isEmpty { return kw }
        }
        return nil
    }
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

    var icon: String {
        switch self {
        case .delivery: return "paperplane.fill"
        case .polling: return "arrow.triangle.2.circlepath"
        case .system: return "gearshape.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

struct BackendLogEntry: Identifiable {
    let id = UUID()
    let category: BackendLogCategory
    let text: String
    let timestamp: Date
}
