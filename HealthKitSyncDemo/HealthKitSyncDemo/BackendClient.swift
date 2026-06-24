//
//  BackendClient.swift
//  HealthKitSyncDemo
//
//  这个文件只负责网络请求：把 Swift 组装好的 JSON POST 到 Python FastAPI 后端。
//

import Foundation

// BackendClientError 表示上传到后端时可能遇到的错误。
enum BackendClientError: LocalizedError {
    // invalidResponse 表示 URLSession 没拿到 HTTPURLResponse。
    case invalidResponse

    // serverError 表示后端返回了非 2xx 状态码。
    case serverError(statusCode: Int, body: String)

    // errorDescription 会显示给用户看。
    var errorDescription: String? {
        // 根据错误类型生成适合 UI 展示的文字。
        switch self {
        case .invalidResponse:
            return "后端响应格式无效。"
        case .serverError(let statusCode, let body):
            return "后端返回错误：HTTP \(statusCode)，\(body)"
        }
    }
}

// BackendClient 是访问 Python 后端的唯一入口。
final class BackendClient {
    // baseURL 是 Python 后端地址。
    // 真机测试时请把 127.0.0.1 改成 Mac 的局域网 IP，例如 http://192.168.1.20:8000。
    private let baseURL = URL(string: "http://192.168.0.40:8000")!

    // session 是系统网络会话；这里用 shared 就足够做最小 demo。
    private let session: URLSession

    // init 允许测试时注入自定义 URLSession；正式 demo 默认用 shared。
    init(session: URLSession = .shared) {
        // 保存网络会话，后续 upload 会使用它发送请求。
        self.session = session
    }

    // upload 把 HealthKit payload POST 到 /healthkit/sync。
    func upload(_ payload: HealthKitSyncPayload) async throws -> HealthKitSyncResponse {
        // endpoint 是 Python FastAPI 接收 HealthKit 数据的接口。
        let endpoint = baseURL.appendingPathComponent("healthkit/sync")

        // request 描述这次 HTTP 请求。
        var request = URLRequest(url: endpoint)

        // Python 后端要求 POST。
        request.httpMethod = "POST"

        // Content-Type 告诉后端 body 是 JSON。
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // JSONEncoder 把 Codable struct 转成 JSON bytes。
        request.httpBody = try JSONEncoder().encode(payload)

        // data(for:) 发送请求并等待后端响应。
        let (data, response) = try await session.data(for: request)

        // URLSession 的 response 需要转成 HTTPURLResponse 才能检查状态码。
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendClientError.invalidResponse
        }

        // 只有 2xx 状态码才认为上传成功。
        guard (200..<300).contains(httpResponse.statusCode) else {
            // bodyText 尽量把后端错误 body 转成人能读懂的字符串。
            let bodyText = String(data: data, encoding: .utf8) ?? "无响应内容"

            // 抛出包含状态码和 body 的错误，方便页面显示。
            throw BackendClientError.serverError(
                statusCode: httpResponse.statusCode,
                body: bodyText
            )
        }

        // 解码 Python 后端返回的 JSON，例如 ok、message、savedPath。
        return try JSONDecoder().decode(HealthKitSyncResponse.self, from: data)
    }
}
