import XCTest
@testable import BossHelperMac

final class ModelsTests: XCTestCase {
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    func testDecodeMetricsResponse() throws {
        let json = """
        {
          "date": "2026-08-13",
          "total": 10,
          "success": 6,
          "danger": 1,
          "warning": 3,
          "delivery_limit": 120,
          "elapsed_seconds": 3725,
          "first_event_at": "2026-08-13T09:00:00",
          "last_event_at": "2026-08-13T10:02:05"
        }
        """.data(using: .utf8)!

        let metrics = try decoder.decode(MetricsResponse.self, from: json)
        XCTAssertEqual(metrics.total, 10)
        XCTAssertEqual(metrics.success, 6)
        XCTAssertEqual(metrics.danger, 1)
        XCTAssertEqual(metrics.warning, 3)
        XCTAssertEqual(metrics.deliveryLimit, 120)
        XCTAssertEqual(metrics.elapsedSeconds, 3725)
    }

    func testDecodeCrawlStatusResponse() throws {
        let json = """
        {
          "state": "waiting_login",
          "run_id": 7,
          "current_keyword": "安全",
          "current_page": 0,
          "scraped_count": 3,
          "error_count": 0,
          "last_message": "请在 30 秒内完成登录或验证码验证",
          "started_at": "2026-08-13T10:00:00",
          "finished_at": null,
          "log_tail": [
            {"level": "info", "message": "正在启动固定 Chrome 浏览器"},
            {"level": "info", "message": "等待手动登录/验证码，完成后自动继续"}
          ]
        }
        """.data(using: .utf8)!

        let status = try decoder.decode(CrawlStatusResponse.self, from: json)
        XCTAssertEqual(status.state, "waiting_login")
        XCTAssertEqual(status.runId, 7)
        XCTAssertEqual(status.currentKeyword, "安全")
        XCTAssertEqual(status.logTail.count, 2)
        XCTAssertEqual(status.logTail.first?.message, "正在启动固定 Chrome 浏览器")
    }

    func testUserFacingBackendErrorMapping() {
        XCTAssertEqual(
            UserFacingBackendError.message(forText: "Address already in use"),
            "端口 5005 已被占用，请关闭占用程序后重试"
        )
        XCTAssertEqual(
            UserFacingBackendError.message(forText: "request timed out"),
            "启动超时，请稍后重试"
        )
        XCTAssertEqual(
            UserFacingBackendError.message(forText: "Network connection lost"),
            "无法连接本地数据服务，请点击重试"
        )
    }

    func testMenuBarPercentText() {
        XCTAssertEqual(MenuBarController.percentText(success: 35, limit: 100), "35%")
        XCTAssertEqual(MenuBarController.percentText(success: 150, limit: 100), "100%")
        XCTAssertEqual(MenuBarController.percentText(success: 0, limit: 100), "0%")
        XCTAssertNil(MenuBarController.percentText(success: 10, limit: 0))
        XCTAssertNil(MenuBarController.percentText(success: 10, limit: nil))
    }
}
