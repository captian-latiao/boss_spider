import Foundation

final class BackendProcessManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var ownsProcess = false
    @Published private(set) var logEntries: [BackendLogEntry] = []
    @Published private(set) var progressEntries: [BackendLogEntry] = []
    @Published var lastError: String?

    private var process: Process?

    var dataDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["BOSS_HELPER_DATA_DIR"],
           !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/BossHelper")
    }

    func startIfNeeded() async {
        guard process == nil else { return }

        if await isBackendHealthy() {
            isRunning = true
            ownsProcess = false
            lastError = nil
            appendLog("检测到后端服务已运行，直接复用")
            return
        }

        start()
    }

    func start() {
        guard process == nil else { return }
        do {
            logEntries.removeAll()
            progressEntries.removeAll()
            appendLog("正在启动后端服务…")
            let command = try backendCommand()
            let newProcess = Process()
            newProcess.executableURL = command.executable
            newProcess.arguments = command.arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            newProcess.standardOutput = stdoutPipe
            newProcess.standardError = stderrPipe
            consume(pipe: stdoutPipe, prefix: "out")
            consume(pipe: stderrPipe, prefix: "err")

            newProcess.terminationHandler = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isRunning = false
                    self?.ownsProcess = false
                    self?.process = nil
                }
            }

            try newProcess.run()
            process = newProcess
            isRunning = true
            ownsProcess = true
            lastError = nil
            appendLog("后端进程已创建，PID \(newProcess.processIdentifier)，等待健康检查")
        } catch {
            lastError = error.localizedDescription
            process = nil
            isRunning = false
            ownsProcess = false
            appendLog("启动后端失败：\(error.localizedDescription)", category: .error)
        }
    }

    private func isBackendHealthy() async -> Bool {
        let client = BackendClient()
        do {
            let health = try await client.health()
            return health.status == "ok"
        } catch {
            return false
        }
    }

    func stop() {
        appendLog("正在停止后端服务…")
        process?.terminate()
        process = nil
        isRunning = false
        ownsProcess = false
        appendLog("已发送停止指令")
    }

    func markStopped() {
        process = nil
        isRunning = false
        ownsProcess = false
        appendLog("后端服务已停止")
    }

    func appendLog(
        _ text: String,
        category: BackendLogCategory = .system
    ) {
        let entry = BackendLogEntry(
            category: category,
            text: text,
            timestamp: Date()
        )
        appendEntry(entry)
    }

    private func appendEntry(_ entry: BackendLogEntry) {
        DispatchQueue.main.async {
            self.logEntries.append(entry)
            if self.logEntries.count > 500 {
                self.logEntries.removeFirst(self.logEntries.count - 500)
            }

            if entry.category != .polling {
                self.progressEntries.append(entry)
                if self.progressEntries.count > 200 {
                    self.progressEntries.removeFirst(self.progressEntries.count - 200)
                }
            }
        }
    }

    private func backendCommand() throws -> (executable: URL, arguments: [String]) {
        let dataArgument = ["--data-dir", dataDirectory.path]

        if let override = ProcessInfo.processInfo.environment["BOSS_HELPER_BACKEND_PATH"],
           !override.isEmpty {
            let overrideURL = URL(fileURLWithPath: override)
            if overrideURL.pathExtension == "py" {
                return (
                    URL(fileURLWithPath: "/usr/bin/env"),
                    ["python3", overrideURL.path] + dataArgument
                )
            }
            return (overrideURL, dataArgument)
        }

        if let bundled = Bundle.main.url(forAuxiliaryExecutable: "boss-helper-backend") {
            return (bundled, dataArgument)
        }

        if let sourceScript = sourceBackendScript() {
            let python = developmentPythonExecutable()
                ?? URL(fileURLWithPath: "/usr/bin/python3")
            return (
                python,
                [sourceScript.path] + dataArgument
            )
        }

        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let scriptURL = currentDirectory
            .appendingPathComponent("../backend/run.py")
            .standardizedFileURL
        return (
            URL(fileURLWithPath: "/usr/bin/env"),
            ["python3", scriptURL.path] + dataArgument
        )
    }

    private func sourceBackendScript() -> URL? {
        guard let macosRoot = macosRootURL() else { return nil }
        let script = macosRoot.appendingPathComponent("backend/run.py")
        return FileManager.default.fileExists(atPath: script.path) ? script : nil
    }

    private func developmentPythonExecutable() -> URL? {
        let systemPython = URL(fileURLWithPath: "/usr/local/bin/python3")
        if FileManager.default.fileExists(atPath: systemPython.path) {
            return systemPython
        }

        return nil
    }

    private func macosRootURL() -> URL? {
        // This source file lives at:
        // <repo>/macos/BossHelperMac/Sources/BossHelperMac/BackendProcessManager.swift
        let sourceFile = URL(fileURLWithPath: #filePath)
        let macosRoot = sourceFile
            .deletingLastPathComponent() // Sources/BossHelperMac
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // BossHelperMac
            .deletingLastPathComponent() // macos
        return FileManager.default.fileExists(atPath: macosRoot.path) ? macosRoot : nil
    }

    private func consume(pipe: Pipe, prefix: String) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                let rawText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let entry = Self.makeEntry(rawText: rawText, prefix: prefix)
                guard entry.category != .polling else { return }
                print("backend-\(entry.text)")
                if entry.category == .error {
                    DispatchQueue.main.async { [weak self] in
                        self?.lastError = rawText
                    }
                }
                self?.appendEntry(entry)
            }
        }
    }

    private static func makeEntry(
        rawText: String,
        prefix: String
    ) -> BackendLogEntry {
        let timestamp = Date()

        if prefix == "err" || rawText.contains("[err]") {
            return BackendLogEntry(
                category: .error,
                text: "[err] \(rawText)",
                timestamp: timestamp
            )
        }

        if rawText.contains("[delivery]") {
            return BackendLogEntry(
                category: .delivery,
                text: cleanDeliveryLine(rawText),
                timestamp: timestamp
            )
        }

        if rawText.contains("[backend]")
            || rawText.contains("/health")
            || rawText.contains("/api/metrics/today")
            || rawText.contains("/api/crawl/status") {
            return BackendLogEntry(
                category: .polling,
                text: "[out] \(rawText)",
                timestamp: timestamp
            )
        }

        return BackendLogEntry(
            category: .system,
            text: "[out] \(rawText)",
            timestamp: timestamp
        )
    }

    private static func cleanDeliveryLine(_ rawText: String) -> String {
        let withoutTag = rawText
            .replacingOccurrences(of: "[delivery]", with: "")
            .trimmingCharacters(in: .whitespaces)
        let company = value(after: "company=", in: withoutTag)
        let jobName = value(after: "job_name=", in: withoutTag)
        return "收到投递数据：\(company) - \(jobName)"
    }

    private static func value(after key: String, in text: String) -> String {
        guard let range = text.range(of: key) else { return "" }
        let suffix = text[range.upperBound...]
        return String(suffix.split(separator: " ", maxSplits: 1).first ?? "")
    }
}
