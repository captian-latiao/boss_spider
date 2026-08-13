import Foundation

enum BackendLaunchState {
    case starting
    case stopping
    case ready
    case stopped
    case failed(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var health: HealthResponse?
    @Published var metrics: MetricsResponse?
    @Published var crawlStatus: CrawlStatusResponse?
    @Published var errorMessage: String?
    @Published var backendState: BackendLaunchState = .starting
    @Published private(set) var hasReachedReady = false

    private var hasLoggedReady = false

    let backendClient = BackendClient()
    let processManager = BackendProcessManager()

    private var pollTask: Task<Void, Never>?

    init() {
        Task {
            await retryBackend()
        }
    }

    deinit {
        pollTask?.cancel()
        processManager.stop()
    }

    var backendRunning: Bool {
        health?.status == "ok"
    }

    var listenAddress: String {
        backendClient.baseURL.absoluteString
    }

    var isStarting: Bool {
        if case .starting = backendState {
            return true
        }
        return false
    }

    var isStopping: Bool {
        if case .stopping = backendState {
            return true
        }
        return false
    }

    var statusTitle: String {
        switch backendState {
        case .starting:
            return "服务启动中"
        case .stopping:
            return "停止中"
        case .ready:
            return "运行中"
        case .stopped:
            return "已停止"
        case .failed:
            return "启动失败"
        }
    }

    func startBackend() async {
        await retryBackend()
    }

    func stopBackend() async {
        if case .stopping = backendState {
            return
        }

        pollTask?.cancel()
        pollTask = nil
        backendState = .stopping

        let gracefullyStopped = (try? await backendClient.shutdown()) != nil
        if !gracefullyStopped {
            processManager.stop()
        }

        await waitForBackendToStop(timeout: 10)
        if processManager.isRunning {
            processManager.stop()
        }
        processManager.markStopped()

        health = nil
        crawlStatus = nil
        errorMessage = nil
        backendState = .stopped
    }

    func retryBackend() async {
        if case .stopping = backendState {
            return
        }

        pollTask?.cancel()
        pollTask = nil
        backendState = .starting
        hasLoggedReady = false
        if !processManager.isRunning {
            await processManager.startIfNeeded()
        }

        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            if await probeBackendHealth() {
                backendState = .ready
                hasReachedReady = true
                logBackendReady()
                startPolling()
                return
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        let reason = processManager.lastError
            ?? "请求超时，无法连接本地后端服务"
        backendState = .failed(UserFacingBackendError.message(forText: reason))
    }

    private func probeBackendHealth() async -> Bool {
        do {
            health = try await backendClient.health()
            return health?.status == "ok"
        } catch {
            health = nil
            return false
        }
    }

    private func logBackendReady() {
        guard !hasLoggedReady else { return }
        hasLoggedReady = true
        let pid = health?.pid ?? 0
        let version = health?.version ?? "--"
        processManager.appendLog(
            "后端服务已就绪，PID \(pid)，版本 \(version)，地址 \(listenAddress)"
        )
    }

    private func waitForBackendToStop(timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            do {
                _ = try await backendClient.health()
            } catch {
                return
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    func refresh() async {
        do {
            health = try await backendClient.health()
            backendState = .ready
            hasReachedReady = true
            errorMessage = nil
        } catch {
            health = nil
            let message = UserFacingBackendError.message(for: error)
            backendState = .failed(message)
            errorMessage = message
        }

        do {
            metrics = try await backendClient.metricsToday()
        } catch {
            metrics = nil
        }

        do {
            crawlStatus = try await backendClient.crawlStatus()
        } catch {
            crawlStatus = nil
        }
    }

    func startCrawl() async {
        do {
            crawlStatus = try await backendClient.startCrawl()
            errorMessage = nil
        } catch {
            errorMessage = "启动爬虫失败：\(error.localizedDescription)"
        }
    }

    func stopCrawl() async {
        do {
            crawlStatus = try await backendClient.stopCrawl()
            errorMessage = nil
        } catch {
            errorMessage = "停止爬虫失败：\(error.localizedDescription)"
        }
    }

    func importPaths(_ paths: [String]) async {
        do {
            _ = try await backendClient.importPaths(paths)
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
}
