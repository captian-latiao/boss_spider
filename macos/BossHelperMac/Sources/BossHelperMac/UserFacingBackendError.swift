import Foundation

enum UserFacingBackendError {
    static func message(for error: Error) -> String {
        message(forText: error.localizedDescription)
    }

    static func message(forText text: String?) -> String {
        let value = (text ?? "").lowercased()

        if value.contains("address already in use") {
            return "端口 5005 已被占用，请关闭占用程序后重试"
        }
        if value.contains("timed out") || value.contains("timeout") {
            return "启动超时，请稍后重试"
        }
        if value.contains("network connection lost")
            || value.contains("could not connect")
            || value.contains("cannot connect")
            || value.contains("connection refused") {
            return "无法连接本地数据服务，请点击重试"
        }

        return "无法连接本地数据服务，请点击重试"
    }
}
