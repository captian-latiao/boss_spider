import Darwin
import Foundation

@MainActor
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

    private var backendPIDFileURL: URL {
        dataDirectory.appendingPathComponent("backend.pid")
    }

    func startIfNeeded() async {
        guard process == nil else { return }

        reclaimStaleBackendIfNeeded()

        if await isBackendHealthy() {
            isRunning = true
            ownsProcess = false
            lastError = nil
            appendLog("检测到后端服务已运行，直接复用")
            return
        }

        reclaimUnhealthyPortOwnerIfNeeded()

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
        if let pid = process?.processIdentifier {
            terminateProcessTree(parentPID: pid, grace: 3.0)
        }
        process = nil
        isRunning = false
        ownsProcess = false
        try? FileManager.default.removeItem(at: backendPIDFileURL)
        appendLog("已发送停止指令")
    }

    func markStopped() {
        process = nil
        isRunning = false
        ownsProcess = false
        appendLog("后端服务已停止")
    }

    private func reclaimStaleBackendIfNeeded() {
        guard let pid = staleBackendPID() else { return }
        appendLog("清理上次遗留的后端进程 PID \(pid)")

        kill(pid, SIGTERM)
        Thread.sleep(forTimeInterval: 0.5)
        if isProcessAlive(pid) {
            kill(pid, SIGKILL)
        }

        try? FileManager.default.removeItem(at: backendPIDFileURL)
    }

    private func staleBackendPID() -> pid_t? {
        guard let data = try? Data(contentsOf: backendPIDFileURL),
              let text = String(data: data, encoding: .utf8),
              let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              pid > 0 else {
            return nil
        }
        return isProcessAlive(pid) ? pid : nil
    }

    /// If port 5005 is occupied by a process that does not answer /health,
    /// terminate it so a fresh backend can bind the port.
    private func reclaimUnhealthyPortOwnerIfNeeded() {
        guard let pid = listeningPIDOnPort5005(),
              pid != process?.processIdentifier else { return }
        appendLog("端口 5005 被无响应进程 PID \(pid) 占用，正在回收")
        terminate(pid: pid, grace: 1.0)
        try? FileManager.default.removeItem(at: backendPIDFileURL)
    }

    private func listeningPIDOnPort5005() -> pid_t? {
        guard let output = runCapture(
            executable: "/usr/sbin/lsof",
            arguments: ["-tiTCP:5005", "-sTCP:LISTEN"]
        ) else { return nil }
        return Self.firstPID(fromOutput: output)
    }

    private func childPIDs(of pid: pid_t) -> [pid_t] {
        guard let output = runCapture(
            executable: "/usr/bin/pgrep",
            arguments: ["-P", "\(pid)"]
        ) else { return [] }
        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { pid_t(String($0)) }
    }

    private func runCapture(executable: String, arguments: [String]) -> String? {
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: executable)
        helper.arguments = arguments
        let pipe = Pipe()
        helper.standardOutput = pipe
        helper.standardError = Pipe()
        do {
            try helper.run()
            helper.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func terminateProcessTree(parentPID: pid_t, grace: TimeInterval) {
        var pids = [parentPID]
        var queue = [parentPID]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            let children = childPIDs(of: current).filter { !pids.contains($0) }
            pids.append(contentsOf: children)
            queue.append(contentsOf: children)
        }

        for pid in pids {
            kill(pid, SIGTERM)
        }

        let deadline = Date().addingTimeInterval(grace)
        while Date() < deadline {
            if pids.allSatisfy({ !isProcessAlive($0) }) { return }
            Thread.sleep(forTimeInterval: 0.1)
        }

        for pid in pids where isProcessAlive(pid) {
            kill(pid, SIGKILL)
        }
    }

    private func terminate(pid: pid_t, grace: TimeInterval) {
        kill(pid, SIGTERM)
        let deadline = Date().addingTimeInterval(grace)
        while Date() < deadline {
            if !isProcessAlive(pid) { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        if isProcessAlive(pid) {
            kill(pid, SIGKILL)
        }
    }

    /// Returns the first PID found in command output (lsof/pgrep format).
    nonisolated static func firstPID(fromOutput output: String) -> pid_t? {
        output
            .split(whereSeparator: \.isNewline)
            .first
            .flatMap { pid_t(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func isProcessAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
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
        let parentArgument = ["--parent-pid", "\(ProcessInfo.processInfo.processIdentifier)"]

        let base: (executable: URL, arguments: [String])
        if let override = ProcessInfo.processInfo.environment["BOSS_HELPER_BACKEND_PATH"],
           !override.isEmpty {
            let overrideURL = URL(fileURLWithPath: override)
            if overrideURL.pathExtension == "py" {
                base = (
                    URL(fileURLWithPath: "/usr/bin/env"),
                    ["python3", overrideURL.path]
                )
            } else {
                base = (overrideURL, [])
            }
        } else if let bundled = Bundle.main.url(forAuxiliaryExecutable: "boss-helper-backend") {
            base = (bundled, [])
        } else if let sourceScript = sourceBackendScript() {
            let python = developmentPythonExecutable()
                ?? URL(fileURLWithPath: "/usr/bin/python3")
            base = (python, [sourceScript.path])
        } else {
            let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let scriptURL = currentDirectory
                .appendingPathComponent("../backend/run.py")
                .standardizedFileURL
            base = (
                URL(fileURLWithPath: "/usr/bin/env"),
                ["python3", scriptURL.path]
            )
        }

        return (base.executable, base.arguments + dataArgument + parentArgument)
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
            let data = (try? handle.read(upToCount: 64 * 1024)) ?? Data()
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                var rawText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if rawText.count > 8000 {
                    rawText = String(rawText.prefix(8000)) + "…"
                }
                let entry = Self.makeEntry(rawText: rawText, prefix: prefix)
                guard entry.category != .polling else { return }
                print("backend-\(entry.text)")
                Task { @MainActor [weak self] in
                    if entry.category == .error {
                        self?.lastError = rawText
                    }
                    self?.appendEntry(entry)
                }
            }
        }
    }

    nonisolated private static func makeEntry(
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

    nonisolated private static func cleanDeliveryLine(_ rawText: String) -> String {
        let withoutTag = rawText
            .replacingOccurrences(of: "[delivery]", with: "")
            .trimmingCharacters(in: .whitespaces)
        let company = value(after: "company=", in: withoutTag)
        let jobName = value(after: "job_name=", in: withoutTag)
        return "收到投递数据：\(company) - \(jobName)"
    }

    nonisolated private static func value(after key: String, in text: String) -> String {
        guard let range = text.range(of: key) else { return "" }
        let suffix = text[range.upperBound...]
        return String(suffix.split(separator: " ", maxSplits: 1).first ?? "")
    }
}
